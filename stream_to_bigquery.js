//import APIs
const BigQuery = require("BigQuery");
const getAllEventData = require("getAllEventData");
const log = require("logToConsole");
const JSON = require("JSON");
const getTimestampMillis = require("getTimestampMillis");
const Object = require("Object");
const getEventData = require('getEventData');
const sendHttpRequest = require('sendHttpRequest');
const getCookieValues = require('getCookieValues');

//for slack messaging
const slackPostHeaders = {'Content-Type': 'application/json'};
const slackUrl = data.slackWebHookUrl;

const connection = getConnection(data.tableId);

let writeData = {};

// add timestamp
if (data.addTimestamp) {
  writeData[data.timestampFieldName] = getTimestampMillis();
}

//custom data
if (data.customData && data.customData.length) {
  for (let i = 0; i < data.customData.length; i += 1) {
    const elem = data.customData[i];
    if (elem.fieldValue || elem.fieldValue === 0) {
      writeData[elem.fieldName] = elem.fieldValue;
    } else {
      Object.delete(writeData, elem.fieldName);
    }
  }
}

//custom data nested fields
if (data.nestedFields && data.nestedFields.length) {
  for (let i = 0; i < data.nestedFields.length; i += 1) {
    const nestEl = data.nestedFields[i];
    const nestStr = nestEl.nestedFieldValue || "[{}]";
    const nestObj = JSON.parse(nestStr);
    writeData[nestEl.nestedFieldName] = nestObj;
  }
}

const rows = [writeData];

const options = {
  ignoreUnknownValues: true,
  skipInvalidRows: false,
};

//streaming insert
BigQuery.insert(connection, rows, options, data.gtmOnSuccess, (err) => {
  log("BigQuery insert error: ", JSON.stringify(err));
  log(err);
  if (data.sendErrorToSlack && data.slackWebHookUrl) {
    const postBody = '{"text": "BigQuery insert error: '+ data.slackMessage +'"}';
    sendHttpRequest(slackUrl, (statusCode, headers, body) => {
    }, {headers: slackPostHeaders, method: 'POST', timeout: 3000}, postBody);
  }
  data.gtmOnFailure();
});

function getConnection(tableId) {
  return {
    projectId: tableId.split(".")[0],
    datasetId: tableId.split(".")[1],
    tableId: tableId.split(".")[2],
  };
}