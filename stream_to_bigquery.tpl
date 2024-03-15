___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "categories": [
    "DATA_WAREHOUSING",
    "ANALYTICS"
  ],
  "securityGroups": [],
  "displayName": "StreamToBigQuery",
  "brand": {
    "id": "github.com_trakken",
    "displayName": ""
  },
  "description": "Stream Data to BigQuery\nIncludes Slack Notification for API errors and support for nested fields for A/B-Test objects and so on.\nNested fields data needs to be a stringyfied object.",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "tableId",
    "displayName": "Table ID String",
    "simpleValueType": true,
    "alwaysInSummary": true,
    "notSetText": "required",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      },
      {
        "type": "REGEX",
        "args": [
          "^.*\\.[A-Za-z0-9_]*\\.[A-Za-z0-9_]*$"
        ],
        "errorMessage": "Letters, numbers and underscores are allowed"
      }
    ],
    "valueHint": "project-id.dataset_id.table_name"
  },
  {
    "type": "SIMPLE_TABLE",
    "name": "customData",
    "displayName": "Data",
    "simpleTableColumns": [
      {
        "defaultValue": "",
        "displayName": "Field Name",
        "name": "fieldName",
        "type": "TEXT",
        "valueHint": "bigquery_column_name",
        "isUnique": true,
        "valueValidators": [
          {
            "type": "NON_EMPTY"
          },
          {
            "type": "REGEX",
            "args": [
              "^[A-Za-z0-9_]*$"
            ],
            "errorMessage": "Letters, numbers and underscores are allowed"
          }
        ]
      },
      {
        "defaultValue": "",
        "displayName": "Field Value",
        "name": "fieldValue",
        "type": "TEXT",
        "valueHint": "column_value"
      }
    ],
    "help": "column keys specified here will potentially override the default keys from the event data"
  },
  {
    "type": "SIMPLE_TABLE",
    "name": "nestedFields",
    "displayName": "Nested Field Data",
    "simpleTableColumns": [
      {
        "defaultValue": "",
        "displayName": "Nested Field Name",
        "name": "nestedFieldName",
        "type": "TEXT",
        "valueHint": "bigquery_column_name",
        "isUnique": true,
        "valueValidators": [
          {
            "type": "NON_EMPTY"
          },
          {
            "type": "REGEX",
            "args": [
              "^[A-Za-z0-9_]*$"
            ],
            "errorMessage": "Letters, numbers and underscores are allowed"
          }
        ]
      },
      {
        "defaultValue": "",
        "displayName": "Nested Field Value",
        "name": "nestedFieldValue",
        "type": "TEXT",
        "valueHint": "column_value"
      }
    ],
    "help": "Add nested field data to populate nested fields in BigQuery. Nested Field Value has to contain a stringyfied array containg JSON objects with keys corresponding to the nested fields in BigQuery."
  },
  {
    "type": "CHECKBOX",
    "name": "addTimestamp",
    "checkboxText": "Add Event Timestamp",
    "simpleValueType": true,
    "help": "This option will add the millisecond timestamp to the event data written to BigQuery. The BigQuery target column will need to be of the INTEGER data type"
  },
  {
    "type": "TEXT",
    "name": "timestampFieldName",
    "displayName": "BigQuery field name of timestamp",
    "simpleValueType": true,
    "enablingConditions": [
      {
        "paramName": "addTimestamp",
        "paramValue": true,
        "type": "EQUALS"
      }
    ],
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      },
      {
        "type": "REGEX",
        "args": [
          "^[A-Za-z0-9_]*$"
        ],
        "errorMessage": "Letters, numbers and underscores are allowed"
      }
    ],
    "defaultValue": "timestamp"
  },
  {
    "type": "GROUP",
    "name": "slack",
    "displayName": "Slack",
    "groupStyle": "NO_ZIPPY",
    "subParams": [
      {
        "type": "CHECKBOX",
        "name": "sendErrorToSlack",
        "checkboxText": "Send BigQuery API error messages to Slack?",
        "simpleValueType": true
      },
      {
        "type": "TEXT",
        "name": "slackWebHookUrl",
        "displayName": "Slack Webhook URL",
        "simpleValueType": true
      },
      {
        "type": "TEXT",
        "name": "slackMessage",
        "displayName": "",
        "simpleValueType": true
      },
      {
        "type": "LABEL",
        "name": "slackLabel",
        "displayName": "Sends error message to Slack channel, when BigQuery API insert fails. \n\u003ca href\u003d\"https://api.slack.com/apps/A04PM23RQS0/incoming-webhooks?success\u003d1\"\u003eMore information\u003c/a\u003e"
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

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


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "access_bigquery",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedTables",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "projectId"
                  },
                  {
                    "type": 1,
                    "string": "datasetId"
                  },
                  {
                    "type": 1,
                    "string": "tableId"
                  },
                  {
                    "type": 1,
                    "string": "operation"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_event_data",
        "versionId": "1"
      },
      "param": [
        {
          "key": "eventDataAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "send_http",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedUrls",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "https://hooks.slack.com/*"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "get_cookies",
        "versionId": "1"
      },
      "param": [
        {
          "key": "cookieAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios: []
setup: ''


___NOTES___

Created on 20/05/2021, 11:29:20


