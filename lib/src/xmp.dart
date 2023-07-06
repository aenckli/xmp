part of xmp;

class XMP {
  ///
  ///Extracts `XMP Data` from the image
  ///
  ///```
  /// Map result = XMP.extract(bytes);
  /// print(result.toString());
  ///
  ///```
  ///                 or
  ///Extracts `XMP RAW Data` from the image
  ///
  ///```
  /// Map result = XMP.extract(bytes, raw: true);
  /// print(result.toString());
  ///
  ///```
  static Map<String, dynamic> extract(Uint8List source, {bool raw = false}) {
      Map<String, dynamic>result = <String, dynamic>{};
      var buffer = latin1.decode(source, allowInvalid: false);
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
          List<XmlNode> rdf_Description =
              xml.descendants.where((node) => node is XmlElement).toList();
          rdf_Description.forEach((element) {
            if (element is XmlElement) {
              _addAttribute(result, element, raw);
            }
          });

          // Other selected known tags
          [_listingTextTags].forEach((headerTag) {
            headerTag.forEach((tag) {
              var tags = xml.findAllElements(tag);
              if (tags.isNotEmpty) {
                tags.forEach((element) {
                  List<XmlNode> textList = element.descendants
                      .where((XmlNode node) =>
                          node is XmlText && !node.value.trim().isEmpty)
                      .toList();
                  textList.forEach((XmlNode text) {
                    _addAttributeList(
                        raw ? tag : camelToNormal(tag), text.value ?? '', result);
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
    // }
  }

  static void _addAttribute(
    Map<String, dynamic> result, XmlElement element, bool raw) {
      List<XmlAttribute> attributeList = element.attributes.toList();

      String headerName = '';

      if (!raw) {
        XmlElement? temporaryElement = element; // XmlElement
        String temporaryName = temporaryElement.name.toString().toLowerCase();

        while (!_envelopeTags.every((element) => element != temporaryName)) {
          temporaryElement = temporaryElement!.parentElement; // parentElement may be null
          if (temporaryElement == null) {
            break;
          }
          temporaryName = temporaryElement.name.toString().toLowerCase();
        }
        headerName = (temporaryElement?.name ?? element.name).toString();
        if (headerName == 'null') {
          throw Exception(
              'If you find this exception, then PLEASE take the pain to post the issue with sample on https://github.com/justkawal/xmp.git. \n\n\t\t\t Thanks for improving ```OpEn SouRce CoMmUniTy```');
        }
      }

      attributeList.forEach((attribute) {
        String attr = attribute.name.toString();
        if (!attr.contains('xmlns:') && !attr.contains('xml:')) {
          String endName = attribute.name.toString();
          String value = attribute.value.toString();
          result[(raw
                  ? '$endName'
                  : '${camelToNormal(headerName)} ${camelToNormal(endName)}')
              .toString()
              .trim()] = value/* ?? ''*/;
        }
      }
    );

    element.children.toList().forEach((XmlNode child) {
      if (child is! XmlText) {
        if (child is XmlElement)
          _addAttribute(result, child, raw);
      }
    });
  }

  static String camelToNormal(String text) {
    if (text.isEmpty) {
      return '';
    }
    // split on `:`
    if (text.contains(':')) {
      text = text.split(':')[1];
    }
    // capitalize first letter
    text = text.capitalize;

    // fetch from replacement for exceptional cases
    var replace = _replacement[text];
    if (replace != null) {
      return replace;
    }

    return text.nameCase();
  }

  static void _addAttributeList(
      String key, String text, Map<String, dynamic> result) {
    text = text.trim();
    if (result[key] == null) {
      result[key] = text;
    } else {
      // check if it is list
      if (result[key] is List) {
        result[key].add(text);
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
