from maven:3.9.6-eclipse-temurin-17 as builder

workdir /app

copy pom.xml .

run mvn dependency:go-offline -B

copy src ./src

run mvn clean package -DskipTests

from eclipse-temurin:17-jre-alpine

workdir /app

copy --from=builder /app/target/*.jar app.jar

expose 8081

entrypoint ["java", "-jar", "app.jar"]
