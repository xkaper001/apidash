import 'package:jinja/jinja.dart' as jj;
import 'package:apidash/models/models.dart' show RequestModel;
import 'package:apidash/utils/utils.dart' show padMultilineString, rowsToMap;
import 'package:apidash/consts.dart';

class PythonRequestCodeGen {
  int kHeadersPadding = 16;
  String kPythonTemplate = '''
import requests
import json

def main():
    url = '{{url}}'

    params = {{params}}

    {{body}}

    headers = {{headers}}

    response = requests.{{method}}(
        url{{request_params}}{{request_headers}}{{request_body}}
    )

    status_code = response.status_code
    if 200 <= status_code < 300:
        print('Status Code:', status_code)
        print('Response Body:', response.text)
    else:
        print('Error Status Code:', status_code)
        print('Error Response Body:', response.text)

main()
''';

  String? getCode(RequestModel requestModel, String defaultUriScheme) {
    try {
      bool hasHeaders = false;
      bool hasBody = false;
      bool hasParams = false;

      String url = requestModel.url;
      if (!url.contains('://') && url.isNotEmpty) {
        url = '$defaultUriScheme://$url';
      }

      var paramsList = requestModel.requestParams;
      String params = '';
      if (paramsList != null) {
        hasParams = true;
        for (var param in paramsList) {
          params += '\n        "${param.k}": "${param.v}",';
        }
      }

      var method = requestModel.method.name.toLowerCase();

      var requestBody = requestModel.requestBody;
      String requestBodyString = '';
      if (requestBody != null) {
        hasBody = true;
        var bodyType = requestModel.requestBodyContentType;
        if (bodyType == ContentType.text) {
          requestBodyString = "data = '''$requestBody'''\n";
        } else if (bodyType == ContentType.json) {
          int index = requestBody.lastIndexOf("}");
          if (requestBody[index - 1] == ",") {
            requestBody = requestBody.substring(0, index - 1) +
                requestBody.substring(index);
          }
          requestBodyString =
              "data = '''$requestBody''' \ndata = json.loads(data)\n";
        }
      }

      var headersList = requestModel.requestHeaders;
      String headers = '';
      if (headersList != null || hasBody) {
        var head = rowsToMap(requestModel.requestHeaders) ?? {};
        if (head.isNotEmpty || hasBody) {
          if (hasBody) {
            head["content-type"] =
                kContentTypeMap[requestModel.requestBodyContentType] ?? "";
          }
          headers = kEncoder.convert(head);
          headers = padMultilineString(headers, kHeadersPadding);
        }
        hasHeaders = headers.isNotEmpty;
      }

      var template = jj.Template(kPythonTemplate);
      var pythonCode = template.render({
        'url': url,
        'params': '{$params \n    }',
        'body': requestBodyString,
        'headers': headers,
        'method': method,
        'request_params': hasParams ? ', params=params' : '',
        'request_headers': hasHeaders ? ', headers=headers' : '',
        'request_body': hasBody ? ', data=data' : '',
      });

      return pythonCode;
    } catch (e) {
      return null;
    }
  }
}
