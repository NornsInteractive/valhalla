import 'package:valhalla/core/services/application_compose_service.dart';
import 'package:valhalla/data/models/application_center.dart';

// Relevant fields of the official Nginx Proxy Manager 2.13.5 template.
final nginxProxyTemplate = ApplicationTemplate(
  application: const CatalogApplication(
    sourceId: 'fixture',
    id: 'org.icewhale.nginxproxymanager',
    title: 'Nginx Proxy Manager',
    composeUrl: '',
  ),
  compose: ApplicationComposeService.parse(r'''
services:
  nginxproxymanager:
    image: jc21/nginx-proxy-manager:2.13.5
    ports: ["80:80", "443:443", "81:81"]
    volumes:
      - type: bind
        source: /DATA/AppData/$AppID/data
        target: /data
      - type: bind
        source: /DATA/AppData/$AppID/etc/letsencrypt
        target: /etc/letsencrypt
x-casaos:
  main: nginxproxymanager
  index: /
  port_map: "81"
'''),
  metadata: const {},
  variables: const {'AppID'},
);
