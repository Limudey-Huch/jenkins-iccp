pipeline {
    agent any

    environment {
        IMAGE_NAME     = "myapp-dev"
        IMAGE_TAG      = "${env.BUILD_NUMBER}"
        CONTAINER_NAME = "tictactoe-dev"
        HOST_PORT      = "5001"
    }

    // No triggers{} block here — under a Multibranch Pipeline, the job's own
    // periodic branch scan already detects new commits on this branch and
    // triggers a build automatically, for every branch it manages.

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

        stage('Deploy to Dev') {
            steps {
                sh '''
                    docker rm -f $CONTAINER_NAME || true
                    docker run -d -p $HOST_PORT:5000 --name $CONTAINER_NAME $IMAGE_NAME:$IMAGE_TAG
                '''
            }
        }
    }

    post {
        always {
            echo "Dev pipeline finished with status: ${currentBuild.currentResult}"
        }
    }
}
