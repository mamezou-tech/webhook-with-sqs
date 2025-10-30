import logging

logger = logging.getLogger()
logger.setLevel('DEBUG')


def lambda_handler(event, context):
    logger.info('Webhook Dummy Application Invoked.')
    logger.debug(f'EVENT: {event.keys()}\n{event}')
    logger.debug(f'CONTEXT: {type(context)}\n{context}')

    logger.info("########## REQUEST DATA ##########")
    logger.info(f'BODY: {event.get("body")}')
    logger.info("##################################")

    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            "Access-Control-Allow-Headers": "Content-Type",
        },
        'body': 'アプリケーションのWebhookが呼び出されました。'
    }
