FROM ubuntu:latest as builder

ARG DT_AG_VERSION

RUN apt-get update && apt-get install -y unzip

ADD https://nexusmil.wdf.sap.corp:8443/nexus/service/local/repositories/deploy.external/content/com/dynatrace/managed/dynatrace-managed-sg-zip/1.169.142.20190522-152808/dynatrace-managed-sg-zip-1.169.142.20190522-152808.zip dynatrace.zip

RUN unzip dynatrace.zip \
  && unzip agents.zip \
  && mv $1.169.142.20190522-152808/sg/unix/Dynatrace-ActiveGate-Linux-x86-*.sh ActiveGate-Installer.sh \
  && rm -rf dynatrace.zip agents.zip $1.169.142.20190522-152808 \
  && chmod +x ActiveGate-Installer.sh \
  && ./ActiveGate-Installer.sh


FROM cloudfoundry/cflinuxfs3

COPY --from=builder /opt/dynatrace/gateway/ /app/gateway/
COPY --from=builder /var/lib/dynatrace/gateway/config/ /app/config/
COPY startup.sh /startup

EXPOSE 9999

ENTRYPOINT /startup
