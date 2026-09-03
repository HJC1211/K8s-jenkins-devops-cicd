FROM eclipse-temurin:8-jre
RUN mkdir -p /hjcc
WORKDIR /hjcc


COPY target/*.jar app.jar

ENV TZ=Asia/Shanghai JAVA_OPTS="-Xms256m -Xmx256m"

EXPOSE 8080

CMD java ${JAVA_OPTS} -Djava.security.egd=file:/dev/./urandom -jar app.jar
