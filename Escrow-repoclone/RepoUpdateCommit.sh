#!/bin/sh
# Copy script to directory
# create file named repo.list
# repo list per line- RepoName $Branch
#
#
#
trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

git config --global credential.helper "cache --timeout=300"
REPO_DIR='/opt/escrow/repos'
REPO_FILE='/opt/escrow/scripts/repo.list'
LOG_DIR='/opt/escrow/scripts/log'
#S3_BUCKET=escrow-clients-apc-loqus
S3_BUCKET=dev-apc-test
if [ ! -f "$REPO_FILE" ] || [ ! -s "$REPO_FILE" ]; then
    "echo Ooooops missing or empty $REPO_FILE ."
    exit 1
fi

if [ -f ../repositories.tar.gz ]; then
    rm ../repositories.tar.gz
fi

echo "$REPO_FILE exists."
echo "Press enter to start the backup and upload process :"
read enter
# Compress Repositories
CompressFiles() {
    tar -zcvf "../repositories.tar.gz" $REPO_DIR >/dev/null
    if [ $? -eq 0 ]; then
        echo "File compressed. proceeding to upload"
    else
        echo FAIL
    fi
}
# Upload tar to s3
UploadToS3() {
    echo "uploading TAR  to S3"
    aws s3 cp ../repositories.tar.gz s3://$S3_BUCKET/
    if [ $? -eq 0 ]; then
        echo "file uploaded, Bye."
        rm ../repositories.tar.gz
    else
        echo FAIL
    fi
}

while IFS='$' read -r repo branch; do
    repo=$(trim $repo)
    branch=$(trim $branch)
    git ls-remote https://github.com/loqusgroup/$repo.git >/dev/null
    exist=$?
    if [ "${exist}" -ne 0 ]; then
        echo "Repo ${repo} does not exist. Check for any typos in the repo list"
        exit 1
    else
        cd $REPO_DIR
        #        rm -rf ${repo}_bk
        #        mv $repo ${repo}_bk
        if [ -d "$repo" ]; then
            rm -rf ${repo}
        fi
        echo "cloning $repo"
        git clone https://github.com/loqusgroup/$repo
        cd $repo
        git checkout $branch
        git pull
        # Cleanup rt-route-it folder
        if [ $repo == "rt-route-it" ]; then
            find . -type d -name "pitData*" ! -iregex '.*-apc' | xargs rm -rf
        fi
        rm -rf .git
        echo "Updating ${repo}."
        cd ..
    fi
done <repo.list
CompressFiles
UploadToS3
