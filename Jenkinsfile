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
                        credentialsId: 'DOCKERHUB_USERNAME',
                        variable: 'DOCKERHUB_USERNAME'
                    ),
                    string(
                        credentialsId: 'mysql-root-password',
                        variable: 'MYSQL_ROOT_PASSWORD'
                    ),
                    string(
                        credentialsId: 'db-password',
                        variable: 'DB_PASSWORD'
                    )
                ]) {
                    sh '''
                        export DB_NAME=test_db
                        export DB_USER=root
                        export DB_PORT=3306
                        export DB_HOST=db_cont
                        export MYSQL_DATABASE=test_db

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
                        credentialsId: 'db-password',
                        variable: 'DB_PASSWORD'
                    )
                ]) {
                    sh '''
                        export DB_NAME=test_db
                        export DB_USER=root
                        export DB_PORT=3306
                        export DB_HOST=db_cont
                        export MYSQL_DATABASE=test_db

                        sleep 200

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

        stage('Deploy to Docker EC2') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'docker-server',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    ),
                    string(
                        credentialsId: 'DOCKERHUB_USERNAME',
                        variable: 'DOCKERHUB_USERNAME'
                    ),
                    string(
                        credentialsId: 'mysql-root-password',
                        variable: 'MYSQL_ROOT_PASSWORD'
                    ),
                    string(
                        credentialsId: 'db-password',
                        variable: 'DB_PASSWORD'
                    )
                ]) {
                    sh '''
                        set -e
                        echo "Copying compose.yaml to Docker EC2..."
                        scp -i "$SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            compose.yaml \
                            "$SSH_USER@3.109.110.26:/home/ubuntu/Docker-django-notes-app/"

                        echo "Deploying application to Docker EC2..."
                        ssh -i "$SSH_KEY" \
                            -o StrictHostKeyChecking=no \
                            "$SSH_USER@3.109.110.26" \
                            "DOCKERHUB_USERNAME='$DOCKERHUB_USERNAME' \
                             DB_PASSWORD='$DB_PASSWORD' \
                             MYSQL_ROOT_PASSWORD='$MYSQL_ROOT_PASSWORD' \
                             bash -s" << 'EOF'
                            set -e
                            export DOCKERHUB_USERNAME="$DOCKERHUB_USERNAME"
                            export DB_NAME="test_db"
                            export DB_USER="root"
                            export DB_PASSWORD="$DB_PASSWORD"
                            export DB_PORT="3306"
                            export DB_HOST="db_cont"
                            export MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD"
                            export MYSQL_DATABASE="test_db"
                            cd /home/ubuntu/Docker-django-notes-app
                            echo "Pulling latest images..."
                            docker compose pull
                            echo "Starting application..."
                            docker compose up -d --remove-orphans
                            echo "Removing unused Docker images..."
                            docker image prune -f
                            echo "Deployment status:"
                            docker compose ps
EOF
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

