#!/usr/bin/env bash
S3_BUCKET_LIST="aws-bigdata-blog"
BLOG_DIR="artifacts/awsblog-beanstalk-gitlab"

pwd
for S3_BUCKET in $S3_BUCKET_LIST; do

  # copy gitlab-setup.sh file.
  aws s3 cp shell/gitlab-setup.sh s3://$S3_BUCKET/${BLOG_DIR}/shell/ --acl public-read

  # Copy cloudformations
  pushd cloudformations;
  aws s3 cp . s3://$S3_BUCKET/${BLOG_DIR}/cloudformations/ --recursive --acl public-read --content-type 'text/x-yaml' #--profile $PROFILE
  popd

done

## Upload the sample nodejs application code base.
# cd ../Final-initial-app/sample-nodejs-app/
# rm -rf node_modules
# rm -rf dist
# cd ../
# zip -r sample-nodejs-app.zip sample-nodejs-app
# cd ../Beanstalk-GitLab

cp -r -p ../Final-initial-app/sample-nodejs-app.zip .
aws s3 cp ../Final-initial-app/sample-nodejs-app.zip s3://$S3_BUCKET/${BLOG_DIR}/baseline-application/ --acl public-read

aws s3 ls s3://aws-bigdata-blog/artifacts/awsblog-beanstalk-gitlab/shell/
aws s3 ls s3://aws-bigdata-blog/artifacts/awsblog-beanstalk-gitlab/baseline-application/
aws s3 ls s3://aws-bigdata-blog/artifacts/awsblog-beanstalk-gitlab/cloudformations/

#npm install @types/node @types/express @types/body-parser --save-dev
#npm run dev
#tsc

### Links in the blog document.
#https://s3.amazonaws.com/aws-bigdata-blog/artifacts/awsblog-beanstalk-gitlab/cloudformations/step1-vpc.yaml
#https://s3.amazonaws.com/aws-bigdata-blog/artifacts/awsblog-beanstalk-gitlab/cloudformations/step2-create-ec2-instance.yaml
#https://s3.amazonaws.com/aws-bigdata-blog/artifacts/awsblog-beanstalk-gitlab/cloudformations/step3-setup-beanstalk.yaml
#https://s3.amazonaws.com/aws-bigdata-blog/artifacts/awsblog-beanstalk-gitlab/shell/gitlab-setup.sh

#https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/new?stackName=Step1-Bean-GitLab-blog&templateURL=https://s3.amazonaws.com/aws-bigdata-blog/artifacts/awsblog-beanstalk-gitlab/cloudformations/step1-vpc.yaml
#https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/new?stackName=Step2-Bean-GitLab-blog&templateURL=https://s3.amazonaws.com/aws-bigdata-blog/artifacts/awsblog-beanstalk-gitlab/cloudformations/step2-create-ec2-instance.yaml
#https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/new?stackName=Step3-Bean-GitLab-blog&templateURL=https://s3.amazonaws.com/aws-bigdata-blog/artifacts/awsblog-beanstalk-gitlab/cloudformations/step3-setup-beanstalk.yaml


#STACK_NAME=cf-${BLOG_DIR}-vpc
#STACK_NAME=eb-step1

#aws cloudformation create-stack \
#  --stack-name $STACK_NAME \
#  --template-url https://${S3_BUCKET_1}.s3.us-east-1.amazonaws.com/${BLOG_DIR}/cloudformations/old-step1-vpc.yaml \
#  --region us-east-1

#echo "Updated stack ${STACK_NAME}"