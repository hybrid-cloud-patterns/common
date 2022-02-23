#!/bin/sh
# shellcheck disable=SC2181,SC3037
# SC2181 (style): Check exit code directly with e.g. 'if mycmd;', not indirectly with $?
# SC3037 (warning): In POSIX sh, echo flags are undefined.

#This script must receive arguments for the following parameters; it is easiest to pass them as environment variables from the command line.
#Example values from the first use for it, in industrial-edge
#
#This script is written to be POSIX-compliant, as not all sh are created equal - many are bash but
#Debian-derivatives use dash which doesn't support some bash syntax
#
#PATTERN=industrial-edge
#TARGET_NAMESPACE=manuela-ci
#COMPONENT=datacenter
#SECRET_NAME='argocd-env'

passwd_resource="secrets/${COMPONENT}-gitops-cluster"
src_ns="${PATTERN}-${COMPONENT}"

# Check for Namespaces and Secrets to be ready (it takes the cluster a few minutes to deploy them)
while true; do
	echo -n "Checking for namespace $TARGET_NAMESPACE to exist..."
	if oc get namespace "$TARGET_NAMESPACE" >/dev/null 2>/dev/null; then
		echo "not yet"
		sleep 2
		continue
	else
		echo "OK"
	fi

	echo -n "Checking for $passwd_resource to be populated in $src_ns..."
	pw=$(oc -n "$src_ns" extract "$passwd_resource" --to=- 2>/dev/null)
	if [ "$?" = 0 ] && [ -n "$pw" ]; then
		echo "OK"
	else
		echo "not yet"
		sleep 2
		continue
	fi

	echo "Conditions met, managing secret $SECRET_NAME in $TARGET_NAMESPACE"
	break
done

user=$(echo admin | base64)
password=$(echo "$pw" | base64)

echo "{ \"apiVersion\": \"v1\", \"kind\": \"Secret\", \"metadata\": { \"name\": \"$SECRET_NAME\", \"namespace\": \"$TARGET_NAMESPACE\" }, \"data\": { \"ARGOCD_PASSWORD\": \"$password\", \"ARGOCD_USERNAME\": \"$user\" }, \"type\": \"Opaque\" }" | oc apply -f-
