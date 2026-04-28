const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');

const client = new SQSClient({ region: process.env.AWS_REGION || 'us-east-1' });
const QUEUE_URL = process.env.ITEM_CREATED_QUEUE_URL;

exports.publishItemCreated = async (item) => {
  // In local dev without SQS, just log and skip
  if (!QUEUE_URL) {
    console.log(JSON.stringify({ level: 'info', event: 'sqs_skipped_no_url', itemId: item.id }));
    return;
  }

  const command = new SendMessageCommand({
    QueueUrl:    QUEUE_URL,
    MessageBody: JSON.stringify({
      event:     'item_created',
      timestamp: new Date().toISOString(),
      data:      item
    })
  });

  await client.send(command);
  console.log(JSON.stringify({ level: 'info', event: 'item_created_published', itemId: item.id }));
};