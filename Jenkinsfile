pipeline {

    agent any

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Start') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'dockerhub-username',
                        variable: 'DOCKERHUB_USERNAME'
                    ),
                    string(
                        credentialsId: 'mysql-root-password',
                        variable: 'MYSQL_ROOT_PASSWORD'
                    ),
                    string(
                        credentialsId: 'mysql-database',
                        variable: 'MYSQL_DATABASE'
                    ),
                    string(
                        credentialsId: 'spring-datasource-url',
                        variable: 'SPRING_DATASOURCE_URL'
                        ),
                    string(
                        credentialsId: 'spring-datasource-username',
                        variable: 'SPRING_DATASOURCE_USERNAME'
                        ),
                    string(
                        credentialsId: 'spring-datasource-password',
                        variable: 'SPRING_DATASOURCE_PASSWORD'
                        )
                ]) {
                    sh '''
                        docker compose up -d --build
                    '''
                }
            }
        }

        stage('Test') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'DOCKERHUB_USERNAME',
                        variable: 'DOCKERHUB_USERNAME'
                    ),
                    string(
                        credentialsId: 'mysql-root-password',
                        variable: 'MYSQL_ROOT_PASSWORD'
                    ),
                         string(
                        credentialsId: 'mysql-database',
                        variable: 'MYSQL_DATABASE'
                    ),
                    string(
                        credentialsId: 'spring-datasource-url',
                        variable: 'SPRING_DATASOURCE_URL'
                        ),
                    string(
                        credentialsId: 'spring-datasource-username',
                        variable: 'SPRING_DATASOURCE_USERNAME'
                        ),
                    string(
                        credentialsId: 'spring-datasource-password',
                        variable: 'SPRING_DATASOURCE_PASSWORD'
                        )
                    
                ]) {
                    sh '''
                        sleep 60

                        curl -f http://localhost:8081
                    '''
                }
            }
        }

        stage('Docker Hub Login') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )
                ]) {
                    sh '''
                        echo "$DOCKER_PASSWORD" | docker login \
                            --username "$DOCKER_USERNAME" \
                            --password-stdin
                    '''
                }
            }
        }

        stage('Push Images') {
            steps {
                withCredentials([
                    string(
                        credentialsId: 'DOCKERHUB_USERNAME',
                        variable: 'DOCKERHUB_USERNAME'
                    )
                ]) {
                    sh '''
                        docker compose push
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes EC2') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'kubernetes-server',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    ),
                    string(
                        credentialsId: 'DOCKERHUB_USERNAME',
                        variable: 'DOCKERHUB_USERNAME'
                    )
                ]) {
                    sh '''
                        set -e
                        echo "Copying Kubernetes manifests to EC2..."
                        scp -i "$SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            -r k8s/* \
                            "$SSH_USER@13.127.214.122:/home/ubuntu/k8s/"

                        echo "Deploying application to Kubernetes..."
                        ssh -i "$SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            "$SSH_USER@13.127.214.122" \
                            "DOCKERHUB_USERNAME='$DOCKERHUB_USERNAME' bash -s" << 'EOF'
                            set -e
                            NAMESPACE="notes-app"
                            DJANGO_IMAGE="$DOCKERHUB_USERNAME/docker-django-notes-app-django_app:latest"
                            NGINX_IMAGE="$DOCKERHUB_USERNAME/django-nginx:latest"
                            cd /home/ubuntu

                            echo "Checking Kubernetes connection..."
                            kubectl get nodes

                            echo "Applying namespace..."
                            kubectl apply -f k8s/namespace.yaml
                            echo "Applying Kubernetes manifests..."
                            kubectl apply -f k8s/ -R

                            echo "Confirming django deployment exists in $NAMESPACE..."
                            kubectl get deployment django --namespace="$NAMESPACE"

                            echo "Updating Django image..."
                            kubectl set image deployment/django \
                                django="$DJANGO_IMAGE" \
                                --namespace="$NAMESPACE"

                            echo "Updating Nginx image..."
                            kubectl set image deployment/nginx-deploy \
                                nginx="$NGINX_IMAGE" \
                                --namespace="$NAMESPACE"

                            echo "Waiting for Django rollout..."
                            kubectl rollout status deployment/django \
                                --namespace="$NAMESPACE" \
                                --timeout=180s

                            echo "Waiting for Nginx rollout..."
                            kubectl rollout status deployment/nginx-deploy \
                                --namespace="$NAMESPACE" \
                                --timeout=180s

                            echo "Kubernetes deployment completed successfully."
                            echo "Pods:"
                            kubectl get pods --namespace="$NAMESPACE"
                            echo "Services:"
                            kubectl get services --namespace="$NAMESPACE"
EOF
                    '''
                }
            }
        }
    }

    post {
        always {
            sh '''
                docker compose down -v || true
            '''
        }
    }
}
