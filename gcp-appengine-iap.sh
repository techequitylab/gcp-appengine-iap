#!/bin/bash
#
# Copyright 2019-2021 Shiyghan Navti. Email shiyghan@techequity.company
#
#################################################################################
####            Explore IAP with Sample AppEngine Application                ####
#################################################################################

# User prompt function
function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=$(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=$(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-appengine-iap
export PROJDIR=`pwd`/gcp-appengine-iap
export SCRIPTNAME=gcp-appengine-iap.sh

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=europe-west6
export GCP_ZONE=europe-west6-a
export APPLICATION_NAME=hellouser
EOF
source $PROJDIR/.env
fi

# Display menu options
while :
do
clear
cat<<EOF
====================================================
Configure Cloud IAP with App Engine Application
----------------------------------------------------
Please enter number to select your choice:
 (1) Enable APIs
 (2) Deploy AppEngine application
 (3) Protect AppEngine application with IAP
 (4) Grant end user access to IAP secured application
 (G) Launch user guide
 (Q) Quit
-----------------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi 
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
export APPLICATION_NAME=$APPLICATION_NAME
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
        echo "*** Application name is $APPLICATION_NAME ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
export APPLICATION_NAME=$APPLICATION_NAME
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
                echo "*** Application name is $APPLICATION_NAME ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT services enable compute.googleapis.com iap.googleapis.com # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT services enable compute.googleapis.com iap.googleapis.com # to enable APIs" | pv -qL 100
    gcloud --project $GCP_PROJECT services enable compute.googleapis.com iap.googleapis.com
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"        
    echo
    echo "$ gcloud --project \$GCP_PROJECT app deploy # to deploy app engine application" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT app browse # to browser the application" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"   
    echo
    echo "$ git clone https://github.com/googlecodelabs/user-authentication-with-iap.git /tmp/hellouser && cp -rf /tmp/hellouser/* $PROJDIR && rm -rf /tmp/hellouser # to fetch code from Github" | pv -qL 100
    git clone https://github.com/googlecodelabs/user-authentication-with-iap.git /tmp/hellouser && cp -rf /tmp/hellouser/* $PROJDIR && rm -rf /tmp/hellouser
    cd $PROJDIR/1-HelloWorld
    echo
    echo "$ cat main.py # to review code" | pv -qL 100
    cat main.py
    echo
    echo "$ cat templates/index.html # to review template file" | pv -qL 100
    cat templates/index.html
    echo
    echo "$ cat templates/privacy.html # to review privacy policy" | pv -qL 100
    cat templates/privacy.html
    echo
    echo "$ gcloud --project $GCP_PROJECT app deploy # to deploy app engine application" | pv -qL 100
    gcloud --project $GCP_PROJECT app deploy
    echo
    echo "$ gcloud --project $GCP_PROJECT app browse # to browse the application" | pv -qL 100
    gcloud --project $GCP_PROJECT app browse
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"   
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Clone repository" | pv -qL 100
    echo "2. Deploy application" | pv -qL 100
    echo "3. Browser application" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT alpha iap oauth-brands create --application_title=\$APPLICATION_NAME --support_email=\$(gcloud config get-value core/account) # to create brand" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT alpha iap oauth-clients create \$BRAND_ID --display_name=\$APPLICATION_NAME # to create oauth clients" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT beta iap web enable --resource-type=app-engine --oauth2-client-id=\$CLIENT_ID --oauth2-client-secret=\$CLIENT_SECRET # to turn on IAP" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT app browse # to browse the application" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"
    export BRAND_NAME=$(gcloud --project $GCP_PROJECT alpha iap oauth-brands list --format="value(name)" 2>/dev/null)
    if [ -z "$BRAND_NAME" ]
    then
        echo
        echo "$ gcloud --project $GCP_PROJECT alpha iap oauth-brands create --application_title=$APPLICATION_NAME --support_email=$(gcloud config get-value core/account) # to create brand" | pv -qL 100
        gcloud --project $GCP_PROJECT alpha iap oauth-brands create --application_title=$APPLICATION_NAME --support_email=$(gcloud config get-value core/account)
        echo
        sleep 10
        export BRAND_ID=$(gcloud --project $GCP_PROJECT alpha iap oauth-brands list --format="value(name)") # to set brand ID
    else
        echo
        export BRAND_ID=$(gcloud --project $GCP_PROJECT alpha iap oauth-brands list --format="value(name)") # to set brand ID
    fi
    export CLIENT_LIST=$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID) 
    if [ -z "$CLIENT_LIST" ]
    then
        echo
        echo "$ gcloud --project $GCP_PROJECT alpha iap oauth-clients create $BRAND_ID --display_name=$APPLICATION_NAME # to create oauth clients" | pv -qL 100
        gcloud --project $GCP_PROJECT alpha iap oauth-clients create $BRAND_ID --display_name=$APPLICATION_NAME
        export CLIENT_ID=$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID --format="value(name)" | awk -F/ '{print $NF}')
        sleep 10
        export CLIENT_SECRET=$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID --format="value(secret)")
    else
        export CLIENT_ID=$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID --format="value(name)" | awk -F/ '{print $NF}')
        export CLIENT_SECRET=$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID --format="value(secret)")
    fi
    echo
    echo "$ gcloud --project $GCP_PROJECT beta iap web enable --resource-type=app-engine --oauth2-client-id=$CLIENT_ID --oauth2-client-secret=\$CLIENT_SECRET # to turn on IAP for your service" | pv -qL 100
    gcloud --project $GCP_PROJECT beta iap web enable --resource-type=app-engine --oauth2-client-id=$CLIENT_ID --oauth2-client-secret=$CLIENT_SECRET
    echo
    echo "$ gcloud --project $GCP_PROJECT app browse # to browse the application in an incognito browser" | pv -qL 100
    gcloud app browse 
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"
    export BRAND_NAME=$(gcloud --project $GCP_PROJECT alpha iap oauth-brands list --format="value(name)" 2>/dev/null)
    export CLIENT=$(gcloud alpha iap oauth-clients list $BRAND_NAME --format="value(name)" 2>/dev/null)
    echo
    echo "$ gcloud --project $GCP_PROJECT alpha iap oauth-clients delete $CLIENT --brand=$BRAND_NAME # to delete oauth clients" | pv -qL 100
    gcloud --project $GCP_PROJECT alpha iap oauth-clients delete $CLIENT --brand=$BRAND_NAME
else
    export STEP="${STEP},3i"
    echo
    echo "1. Create OAuth brand" | pv -qL 100
    echo "2. Configure oauth2 client secret" | pv -qL 100
    echo "3. Turn on IAP for the service" | pv -qL 100
    echo "4. Browse application" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member=user:\$(gcloud config get-value core/account) --role=roles/iap.httpsResourceAccessor # to grant Cloud IAP/IAP-Secured Web App User role" | pv -qL 100
    echo
    echo "$ gcloud --project $GCP_PROJECT app deploy # to deploy app engine application" | pv -qL 100
    echo
    echo "$ gcloud --project $GCP_PROJECT app browse # to browser the application in an incognito browser" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:\$(gcloud config get-value core/account) --role=roles/iap.httpsResourceAccessor # to grant Cloud IAP/IAP-Secured Web App User role" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member=user:$(gcloud config get-value core/account) --role=roles/iap.httpsResourceAccessor
    export DOMAIN=$(gcloud app describe | grep defaultHostname | awk '{print $2}')
    echo
    echo "*** Navigate to \"https://$DOMAIN/_gcp_iap/clear_login_cookie\" to access application while clearing cookie cache ***" | pv -qL 100
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    cd $PROJDIR/2-HelloUser
    echo
    echo "$ cat main.py # to review code" | pv -qL 100
    cat main.py
    echo
    echo "$ cat templates/index.html # to review code" | pv -qL 100
    cat templates/index.html
    echo
    echo "$ gcloud app deploy # to deploy app engine application" | pv -qL 100
    gcloud app deploy
    echo
    echo "$ gcloud app browse # to browse the application in an incognito browser" | pv -qL 100
    gcloud app browse
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"
    echo
    echo "$ gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=user:\$(gcloud config get-value core/account) --role=roles/iap.httpsResourceAccessor # to revoke Cloud IAP/IAP-Secured Web App User role" | pv -qL 100
    gcloud projects remove-iam-policy-binding $GCP_PROJECT --member=user:$(gcloud config get-value core/account) --role=roles/iap.httpsResourceAccessor
else
    export STEP="${STEP},4i"
    echo
    echo "1. Grant Cloud IAP/IAP-Secured Web App User role" | pv -qL 100
    echo "2. Access application and clear cookie cache" | pv -qL 100
    echo "3. Deploy app engine application" | pv -qL 100
    echo "4. Browse application" | pv -qL 100
fi
eend=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"-5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"
    echo
    echo "$ gcloud --project \$GCP_PROJECT beta iap web disable --resource-type=app-engine # to disable IAP" | pv -qL 100
    echo
    echo "$ curl -X GET https://\$DOMAIN -H \"X-Goog-Authenticated-User-Email: totally fake email\" # to invoke endpoint with fake credentials" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT app deploy # to deploy app engine application" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT beta iap web enable --resource-type=app-engine --oauth2-client-id=\$CLIENT_ID --oauth2-client-secret=\$CLIENT_SECRET # to enable IAP" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT app browse # to browser the application in an incognito browser" | pv -qL 100
    echo
    echo "$ curl -X GET https://\$DOMAIN -H \"X-Goog-Authenticated-User-Email: totally fake email\" # to invoke endpoint with fake credentials" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"
    echo
    echo "$ gcloud --project $GCP_PROJECT beta iap web disable --resource-type=app-engine # to disable IAP" | pv -qL 100
    gcloud --project $GCP_PROJECT beta iap web disable --resource-type=app-engine
    echo
    export DOMAIN=$(gcloud app describe | grep defaultHostname | awk '{print $2}')
    echo "$ curl -X GET https://$DOMAIN -H \"X-Goog-Authenticated-User-Email: totally fake email\" # to invoke endpoint with fake credentials" | pv -qL 100
    curl -X GET https://$DOMAIN -H "X-Goog-Authenticated-User-Email: totally fake email" 
    cd $PROJDIR/3-HelloVerifiedUser
    echo
    echo "$ cat main.py # to review code to validate end user identity" | pv -qL 100
    cat main.py
    echo
    echo "$ cat templates/index.html # to review code" | pv -qL 100
    cat templates/index.html
    echo
    sed -i "/automatic_scaling/d" app.yaml
    echo "automatic_scaling:" >> app.yaml
    sed -i "/max_num_instances/d" app.yaml
    echo "  max_num_instances: 5" >> app.yaml
    sed -i "/min_num_instances/d" app.yaml
    echo "  min_num_instances: 1" >> app.yaml
    echo "$ gcloud --project $GCP_PROJECT app deploy # to deploy app engine application" | pv -qL 100
    gcloud app deploy
    export CLIENT_ID=$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID --format="value(name)" | awk -F/ '{print $NF}')
    export CLIENT_SECRET=$(gcloud --project $GCP_PROJECT alpha iap oauth-clients list $BRAND_ID --format="value(secret)")
    echo
    echo "$ gcloud beta iap web enable --resource-type=app-engine --oauth2-client-id=$CLIENT_ID --oauth2-client-secret=\$CLIENT_SECRET # to enable IAP" | pv -qL 100
    gcloud --project $GCP_PROJECT beta iap web enable --resource-type=app-engine --oauth2-client-id=$CLIENT_ID --oauth2-client-secret=$CLIENT_SECRET
    echo
    echo "$ gcloud --project $GCP_PROJECT app browse # to browser the application in an incognito browser" | pv -qL 100
    gcloud app browse
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    export DOMAIN=$(gcloud app describe | grep defaultHostname | awk '{print $2}')
    echo
    echo "$ curl -X GET https://$DOMAIN -H \"X-Goog-Authenticated-User-Email: totally fake email\" # to invoke endpoint with fake credentials" | pv -qL 100
    curl -X GET https://$DOMAIN -H "X-Goog-Authenticated-User-Email: totally fake email"
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},5i"
    echo
    echo "1. Disable IAP" | pv -qL 100
    echo "2. Invoke endpoint with fake credentials" | pv -qL 100
    echo "3. Deploy app engine application" | pv -qL 100
    echo "4. Enable IAP" | pv -qL 100
    echo "5. Browse application" | pv -qL 100
    echo "6. Invoke endpoint with fake credentials" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app
 
Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
