part of xmp;

class XMP {
  ///
  ///Extracts `XMP Data` from the image
  ///
  ///````
  /// Map result = XMP.extract(bytes);
  /// print(result.toString());
  ///
  ///````
  ///                 or
  ///Extracts `XMP RAW Data` from the image
  ///
  ///````
  /// Map result = XMP.extract(bytes, raw: true);
  /// print(result.toString());
  ///
  ///````
  static Map<String, dynamic> extract(Uint8List source, {bool raw = false}) {
    if (source is! Uint8List) {
      throw Exception('Not a Uint8List');
    } else {
      var result = <String, dynamic>{};
      var buffer = utf8.decode(source, allowMalformed: true);
      int offsetBegin = buffer.indexOf(_markerBegin);
      if (offsetBegin != -1) {
        int offsetEnd = buffer.indexOf(_markerEnd);
        if (offsetEnd != -1) {
          var xmlBuffer =
              buffer.substring(offsetBegin, offsetEnd + _markerEnd.length);

          XmlDocument xml;
          try {
            xml = XmlDocument.parse(xmlBuffer);
          } catch (e) {
            return {'Exception': e.toString()};
          }

          // First rdf:Description
          var rdf_Description =
              xml.descendants.where((node) => node is XmlElement).toList();
          rdf_Description.forEach((element) {
            _addAttribute(result, element, raw);
          });

          // Other selected known tags
          [_listingTextTags].forEach((headerTag) {
            headerTag.forEach((tag) {
              var tags = xml.findAllElements(tag);
              if (tags.isNotEmpty) {
                tags.forEach((element) {
                  var textList = element.descendants
                      .where((node) =>
                          node is XmlText && !node.text.trim().isEmpty)
                      .toList();
                  textList.forEach((text) {
                    _addAttributeList(
                        raw ? tag : _camelToNormal(tag), text.text, result);
                  });
                });
              }
            });
          });
          return result;
        } else {
          return {'Exception': 'Invalid Data'};
        }
      } else {
        return {'Exception': 'Invalid Data'};
      }
    }
  }

  static void _addAttribute(
      Map<String, dynamic> result, XmlElement element, bool raw) {
    var attributeList = element.attributes.toList();
    var temporaryElement = element;
    var temporaryName = temporaryElement.name.toString().toLowerCase();

    while (!_envelopeTags.every((element) => element != temporaryName)) {
      temporaryElement = temporaryElement.parentElement;
      if (temporaryElement == null) {
        break;
      }
      temporaryName = temporaryElement?.name?.toString()?.toLowerCase();
    }
    var headerName = (temporaryElement?.name ?? element.name).toString();
    if (headerName == 'null') {
      throw Exception(
          'If you find this exception, then PLEASE take the pain to post the issue with sample on https://github.com/justkawal/xmp.git. \n\n\t\t\t Thanks for improving ```OpEn SouRce CoMmUniTy```');
    }

    attributeList.forEach((attribute) {
      var attr = attribute.name.toString();
      if (!attr.contains('xmlns:') && !attr.contains('xml:')) {
        var endName = attribute.name.toString();
        var value = attribute.value.toString().trim();
        if (value != '') {
          result[(raw
                  ? '$endName'
                  : '${_camelToNormal(headerName)} ${_camelToNormal(endName)}')
              .toString()
              .trim()] = value;
        }
      }
    });

    element.children.toList().forEach((child) {
      if (child is! XmlText) {
        _addAttribute(result, child, raw);
      }
    });
  }

  static String _camelToNormal(String text) {
    if (text == null || text.isEmpty) {
      return '';
    }
    // split on `:`
    if (text.contains(':')) {
      text = text.split(':')[1];
    }
    // capitalize first letter
    text = _capitalize(text);

    // fetch from replacement for exceptional cases
    var replace = _replacement[text];
    if (replace != null) {
      return replace;
    }

    // regExp for converting camel Case to normal case
    RegExp exp = RegExp(
        r'((?<=[a-z])[0-9])|((?<=[0-9])[a-z])|((?<=[A-Z])[0-9])|((?<=[0-9])[A-Z])|((?<=[a-z])[A-Z])');
    String result = text.replaceAllMapped(exp, (Match m) => (' ' + m.group(0)));
    return _capitalize(result);
  }

  static String _capitalize(String text) {
    if (text == null || text == '') {
      return '';
    }
    return text[0].toUpperCase() + text.substring(1);
  }

  static void _addAttributeList(
      String key, String text, Map<String, dynamic> result) {
    text = text.trim();
    if (result[key] == null) {
      result[key] = text;
    } else {
      // check if it is list
      if (result[key] is List) {
        if (result[key].indexOf(text) == -1) {
          result[key].add(text);
        }
      } else {
        var temporaryValue = result[key].toString();
        if (temporaryValue.trim() != text) {
          // remove the key
          result.remove(key);
          // re-initialize the key with new empty data-type
          result[key] = <String>[];
          // add the new list to the key
          result[key].addAll([temporaryValue, text]);
        }
      }
    }
  }
}
