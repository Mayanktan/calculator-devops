pipeline {
    agent any

    environment {
        // Change these two values to your own
        DOCKERHUB_USER = 'mayanktan'
        NOTIFY_EMAIL   = 'mayanktanwar01234@gmail.com'

        IMAGE_NAME = "${DOCKERHUB_USER}/calculator-devops"
        IMAGE_TAG  = "${env.BUILD_NUMBER}"
        FULL_IMAGE = "${IMAGE_NAME}:${IMAGE_TAG}"
    }

    options {
        skipDefaultCheckout()       // the Checkout stage below does it
        disableConcurrentBuilds()   // one deploy at a time
        timestamps()
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '15'))
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log -1 --oneline'
            }
        }

        stage('Build') {
            steps {
                sh 'mvn -B -ntp clean package -DskipTests'
            }
        }

        stage('Test') {
            steps {
                sh 'mvn -B -ntp test'
            }
            post {
                always {
                    // Publish results even when tests fail
                    junit testResults: 'target/surefire-reports/*.xml', allowEmptyResults: false
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh "docker build -t ${FULL_IMAGE} -t ${IMAGE_NAME}:latest ."
                sh "docker images ${IMAGE_NAME}"
            }
        }

        stage('Push') {
            steps {
                withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DH_USER',
                        passwordVariable: 'DH_PASS')]) {
                    sh '''
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
                        docker push "$IMAGE_NAME:$IMAGE_TAG"
                        docker push "$IMAGE_NAME:latest"
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                // 'up -d' on a running stack only recreates what changed,
                // so re-runs are safe. '--wait' blocks until healthy.
                sh '''
                    export DOCKER_IMAGE="$IMAGE_NAME:$IMAGE_TAG"
                    echo "Deploying $DOCKER_IMAGE ..."
                    docker compose up -d --remove-orphans --wait
                    docker compose ps

                    # Verify health through the nginx proxy
                    for i in $(seq 1 12); do
                        if curl -fsS http://localhost/actuator/health | grep -q '"status":"UP"'; then
                            echo "Healthy after $i tries"
                            exit 0
                        fi
                        sleep 5
                    done
                    echo "Not healthy after 1 min"
                    docker compose logs
                    exit 1
                '''
            }
        }
    }

    post {
        success {
            emailext(
                subject: "[Jenkins] SUCCESS: ${JOB_NAME} #${BUILD_NUMBER}",
                body: """
                    <h2 style="color:#2E8B57">Build succeeded</h2>
                    <ul>
                        <li><b>Job:</b> ${JOB_NAME}</li>
                        <li><b>Build:</b> #${BUILD_NUMBER}</li>
                        <li><b>Image:</b> ${FULL_IMAGE}</li>
                        <li><b>URL:</b> <a href="${BUILD_URL}">${BUILD_URL}</a></li>
                    </ul>
                """,
                to: "${NOTIFY_EMAIL}",
                mimeType: 'text/html'
            )
        }
        failure {
            emailext(
                subject: "[Jenkins] FAILED: ${JOB_NAME} #${BUILD_NUMBER}",
                body: """
                    <h2 style="color:#B23A48">Build failed</h2>
                    <ul>
                        <li><b>Job:</b> ${JOB_NAME}</li>
                        <li><b>Build:</b> #${BUILD_NUMBER}</li>
                        <li><b>Console:</b> <a href="${BUILD_URL}console">${BUILD_URL}console</a></li>
                    </ul>
                """,
                to: "${NOTIFY_EMAIL}",
                mimeType: 'text/html'
            )
        }
        always {
            // Remove old images so the agent's disk doesn't fill up
            sh 'docker image prune -f --filter "until=72h" || true'
        }
    }
}
