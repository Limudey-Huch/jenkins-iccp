pipeline {
    agent any

    environment {
        IMAGE_NAME     = "myapp-prod"
        IMAGE_TAG      = "${env.BUILD_NUMBER}"
        CONTAINER_NAME = "tictactoe-prod"
        HOST_PORT      = "5000"
    }

    // No triggers block on purpose — production deploys happen deliberately
    // (a human clicks Build Now), never automatically on every commit.

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'docker build -t $IMAGE_NAME:$IMAGE_TAG .'
            }
        }

        stage('Test') {
            steps {
                sh 'docker run --rm -v $WORKSPACE:/app -w /app $IMAGE_NAME:$IMAGE_TAG pytest --junitxml=results.xml'
            }
            post {
                always {
                    junit 'results.xml'
                }
            }
        }

        stage('Approval') {
            steps {
                input message: "Deploy build #${env.BUILD_NUMBER} to PRODUCTION?", ok: "Deploy"
            }
        }

        stage('Deploy to Prod') {
            steps {
                sh '''
                    docker rm -f $CONTAINER_NAME || true
                    docker run -d -p $HOST_PORT:5000 --name $CONTAINER_NAME $IMAGE_NAME:$IMAGE_TAG
                '''
            }
        }
    }

    post {
        success {
            echo "Production deploy #${env.BUILD_NUMBER} succeeded."
        }
        failure {
            echo "Production pipeline failed — nothing was deployed."
        }
    }
}
