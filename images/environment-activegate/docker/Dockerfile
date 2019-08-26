FROM ubuntu:latest as builder

ARG DT_AG_VERSION

RUN apt-get update && apt-get install -y unzip

ADD https://nexusmil.wdf.sap.corp:8443/nexus/service/local/repositories/deploy.external/content/com/dynatrace/managed/dynatrace-managed-sg-zip/${DT_AG_VERSION}/dynatrace-managed-sg-zip-${DT_AG_VERSION}.zip dynatrace.zip

RUN unzip dynatrace.zip \
  && unzip agents.zip \
  && mv ${DT_AG_VERSION}/sg/unix/Dynatrace-ActiveGate-Linux-x86-*.sh ActiveGate-Installer.sh \
  && rm -rf dynatrace.zip agents.zip ${DT_AG_VERSION} \
  && chmod +x ActiveGate-Installer.sh \
  && ./ActiveGate-Installer.sh


FROM cloudfoundry/cflinuxfs3

COPY --from=builder /opt/dynatrace/gateway/ /app/gateway/
COPY --from=builder /var/lib/dynatrace/gateway/config/ /app/config/
COPY startup.sh /startup

EXPOSE 9999

ENTRYPOINT /startup
