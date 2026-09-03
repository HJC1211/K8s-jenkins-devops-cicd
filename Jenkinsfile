pipeline {
    agent {
        kubernetes {
            label 'maven'
        }
    }
    parameters {
        gitParameter name: 'BRANCH_NAME', branch: '', branchFilter: '.*', defaultValue: 'origin/master', description: '请选择要发布的分支', quickFilterEnabled: false, selectedValue: 'NONE', tagFilter: '*', type: 'PT_BRANCH'
        string(name: 'TAG_NAME', defaultValue: 'snapshot', description: '标签名称，必须以 v 开头')
    }
    environment {
        DOCKER_CREDENTIAL_ID = 'harbor-user-pass'
        GIT_REPO_URL = '192.168.142.152:28080'
        GIT_CREDENTIAL_ID = 'git-user-pass'
        KUBECONFIG_CREDENTIAL_ID = '9615b7f8-8237-45b5-a7aa-4ef1f209711c'
        REGISTRY = '192.168.142.156:8858'
        DOCKERHUB_NAMESPACE = 'hjc'
        APP_NAME = 'k8s-cicd'
        SONAR_SERVER_URL = '192.168.142.152:32267'
        SONAR_CREDENTIAL_ID = 'sonarqube-token'
    }
     stage('checkout scm') {
            steps {
                checkout scmGit(branches: [[name: "$BRANCH_NAME"]], extensions: [], userRemoteConfigs: [[credentialsId: "$GIT_CREDENTIAL_ID", url: 'http://192.168.142.152:28080/gitlab-instance-a1f2e959/k8s-cicd.git']])
            }
        }
    stages {
        stage('unit test') {
            steps {
                sh 'mvn clean test'
            }
        }
        stage('sonarqube analysis') {
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    withCredentials([string(credentialsId: "$SONAR_CREDENTIAL_ID", variable: 'SONAR_TOKEN')]) {
                        withSonarQubeEnv('sonarqube') {
                            sh 'mvn sonar:sonar -Dsonar.projectKey=$APP_NAME '
                        }
                    }
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        stage('build & push') {
            steps {
                sh 'mvn clean package -DskipTests '
                sh 'docker build -f Dockerfile -t $REGISTRY/$DOCKERHUB_NAMESPACE/$APP_NAME:SNAPSHOT-$BUILD_NUMBER .'
                withCredentials([usernamePassword(passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME', credentialsId: "$DOCKER_CREDENTIAL_ID")]) {
                    sh 'echo "$DOCKER_PASSWORD" | docker login $REGISTRY -u "$DOCKER_USERNAME" --password-stdin'
                    sh 'docker push $REGISTRY/$DOCKERHUB_NAMESPACE/$APP_NAME:SNAPSHOT-$BUILD_NUMBER'
                }
            }
        }
        stage('push latest') {
            steps {
                sh 'docker tag $REGISTRY/$DOCKERHUB_NAMESPACE/$APP_NAME:SNAPSHOT-$BUILD_NUMBER $REGISTRY/$DOCKERHUB_NAMESPACE/$APP_NAME:latest'
                sh 'docker push $REGISTRY/$DOCKERHUB_NAMESPACE/$APP_NAME:latest'
            }
        }
        stage('deploy to dev') {
            steps {
                input(id: 'deploy-to-dev', message: 'deploy to dev?')
                sh '''
                    sed -i "s#REGISTRY#$REGISTRY#" deploy/cicd-dev.yaml
                    sed -i "s#DOCKERHUB_NAMESPACE#$DOCKERHUB_NAMESPACE#" deploy/cicd-dev.yaml
                    sed -i "s#APP_NAME#$APP_NAME#" deploy/cicd-dev.yaml
                    sed -i "s#BUILD_NUMBER#$BUILD_NUMBER#" deploy/cicd-dev.yaml
                    kubectl apply -f deploy/cicd-dev.yaml
                '''
            }
        }
        stage('push with tag') {
            when {
                expression { return params.TAG_NAME =~ /v.*/ }
            }
            steps {
                input(id: 'release-image-with-tag', message: 'release image with tag?')
                withCredentials([usernamePassword(credentialsId: "$GIT_CREDENTIAL_ID", passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
                    sh 'git config --global user.email "3526443628@qq.com"'
                    sh 'git config --global user.name "hjc"'
                    sh 'git tag -a $TAG_NAME -m "$TAG_NAME"'
                    sh 'git push http://$GIT_USERNAME:$GIT_PASSWORD@$GIT_REPO_URL/gitlab-instance-a1f2e959/k8s-cicd.git --tags --ipv4'
                }
                sh 'docker tag $REGISTRY/$DOCKERHUB_NAMESPACE/$APP_NAME:SNAPSHOT-$BUILD_NUMBER $REGISTRY/$DOCKERHUB_NAMESPACE/$APP_NAME:$TAG_NAME'
                sh 'docker push $REGISTRY/$DOCKERHUB_NAMESPACE/$APP_NAME:$TAG_NAME'
            }
        }
        stage('deploy to production') {
            when {
                expression { return params.TAG_NAME =~ /v.*/ }
            }
            steps {
                input(id: 'deploy-to-production', message: 'deploy to production?')
                sh '''
                    sed -i "s#REGISTRY#$REGISTRY#" deploy/cicd.yaml
                    sed -i "s#DOCKERHUB_NAMESPACE#$DOCKERHUB_NAMESPACE#" deploy/cicd.yaml
                    sed -i "s#APP_NAME#$APP_NAME#" deploy/cicd.yaml
                    sed -i "s#TAG_NAME#$TAG_NAME#" deploy/cicd.yaml
                    kubectl apply -f deploy/cicd.yaml
                '''
            }
        }
    }
}
