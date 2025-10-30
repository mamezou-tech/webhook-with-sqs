import logging
import urllib.request
import urllib.error

# CONSTANTS
API_GATEWAY_ENDPOINT = '${apigw_endpoint}'

PATH_MAP = {
    '${message_group_id}': {
        'webhook-application': '${application_route}'
    },
}

logger = logging.getLogger()
logger.setLevel('${log_level}'.upper())


def lambda_handler(event, context):
    ''' SQSからメッセージを取得してSSSのサービスのWebhookを呼び出すLambda関数。

        Parameters
        ----------
        event: SQSイベント
        context: Lambda関数のコンテキスト

        Returns
        -------
        dict
            HTTPのステータスコードとメッセージ

        Raises
        ------
        Exception
            イベントが処理できない場合
    '''
    logger.info('Webhook Event Producer Invoked.')
    logger.debug(f'EVENT: {event.keys()}\n{event}')
    logger.debug(f'CONTEXT: {type(context)}\n{context}')

    # SQSイベントからデータを抽出
    urls, body = extract_data_from_event(event)

    # リクエストデータをエンコード
    data = body.encode()

    # アプリケーションWebhookに対するAPI Gatewayエンドポイントを呼び出す
    for k, v in urls.items():
        res = send_request(v, data)

        if not res:
            raise Exception(f'API Gatewayの呼び出しに失敗しました: {k}')
    else:
        return {
            'status': 200,
            'body': 'Success to Consume All Messages'
        }


def extract_data_from_event(event):
    ''' SQSイベントからメッセージグループIDとデータを抽出

        Parameters
        ----------
        event: SQSイベント

        Returns
        -------
        tuple
            API GatewayのエンドポイントURLとデータの組

        Raises
        ------
        Exception
            イベントが処理できない場合
    '''
    if 'Records' not in event:
        logger.error(f'SQS以外からのイベントを検出しました: {event}')
        raise Exception('処理できないメッセージです')

    if len(event['Records']) != 1:
        logger.error(f'複数のメッセージを検出しました: {len(event["Records"])}')
        raise Exception('処理できないメッセージです')

    record = event['Records'][0]

    if 'attributes' not in record or \
       'MessageGroupId' not in record['attributes'] or \
       record['attributes']['MessageGroupId'] not in PATH_MAP:
        logger.error(f'メッセージグループIDが不明です: {record.get("MessageGroupId") }')
        raise Exception('処理できないメッセージです')

    mgid = record['attributes']['MessageGroupId']

    if 'body' not in record:
        logger.error(f'想定外のメッセージフォーマットを検出しました: {record.keys()}')
        raise Exception('処理できないメッセージです')

    urls = {k: f'{API_GATEWAY_ENDPOINT}{v}' for k,
            v in PATH_MAP.get(mgid).items()}

    return urls, record['body']  # ATTENTION: body is string


def send_request(endpoint, data):
    ''' エンドポイントへHTTP POSTで送信

        Parameters
        ----------
        endpoint: 送信先のエンドポイント
        data: 送信するデータ

        Returns
        -------
        dict
            HTTPのステータスコードとメッセージ
    '''
    # リクエストを作成
    headers = {'Content-Type': 'application/json'}
    request = urllib.request.Request(
        endpoint, headers=headers, data=data, method='POST')

    # リクエストを送信し、レスポンスを取得
    try:
        with urllib.request.urlopen(request) as response:
            body = response.read().decode()

    except urllib.error.HTTPError as e:
        # 4xx or 5xx
        logger.error(f'REST APIの呼び出しに失敗しました（{e.code}）。: {endpoint}')
        logger.exception(e)
        raise e

    except urllib.error.URLError as e:
        # 通信エラー
        logger.error(f'通信エラー: {endpoint} - {e.reason}')
        logger.exception(e)
        raise e

    else:
        # サービス呼び出し成功
        return {
            "status": response.status,
            "body": body
        }
