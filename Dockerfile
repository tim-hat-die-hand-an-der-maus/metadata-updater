FROM openjdk:11.0.15-jre-slim

WORKDIR /usr/app

RUN addgroup troupe \
    && adduser --no-create-home --disabled-password --shell /bin/bash --gecos 'ballerina' --ingroup troupe ballerina \
    && apt-get update \
    && apt-get install -y wget unzip \
    && wget -q https://dist.ballerina.io/downloads/2201.0.0/ballerina-2201.0.0-swan-lake.zip \
    && unzip -q ballerina-2201.0.0-swan-lake.zip \
    && mv ballerina-2201.0.0-swan-lake /opt/ballerina \
    && rm -rf /var/cache/apt/*

ADD Ballerina.toml .
ADD Dependencies.toml .
ADD main.bal .

RUN /opt/ballerina/bin/bal build
CMD ["java", "-jar", "target/bin/app.jar"]
