FROM eclipse-temurin:8-jre
WORKDIR /app
COPY target/eventflow-ticketing-0.0.1-SNAPSHOT.jar /app/app.jar
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
