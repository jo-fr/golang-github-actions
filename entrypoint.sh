#!/bin/sh
set -e

# ------------------------
#  Environments
# ------------------------
RUN=$1
WORKING_DIR=$2
SEND_COMMNET=$3
GITHUB_TOKEN=$4
FLAGS=$5
IGNORE_DEFER_ERR=$6

COMMENT=""
SUCCESS=0


# ------------------------
#  Functions
# ------------------------
# send_comment is send ${comment} to pull request.
# this function use ${GITHUB_TOKEN}, ${COMMENT} and ${GITHUB_EVENT_PATH}
send_comment() {
	PAYLOAD=$(echo '{}' | jq --arg body "${COMMENT}" '.body = $body')
	COMMENTS_URL=$(cat ${GITHUB_EVENT_PATH} | jq -r .pull_request.comments_url)
	curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/json" --data "${PAYLOAD}" "${COMMENTS_URL}" > /dev/null
}

# mod_download is getting go modules using go.mod.
mod_download() {
	if [ ! -e go.mod ]; then go mod init local; fi
	go mod download
	if [ $? -ne 0 ]; then exit 1; fi
}

# check_errcheck is excute "errcheck" and generate ${COMMENT} and ${SUCCESS}
check_errcheck() {
	if [ "${IGNORE_DEFER_ERR}" = "true" ]; then
		IGNORE_COMMAND="| grep -v defer"
	fi

	set +e
	# exclude tests folder by default
	OUTPUT=$(sh -c "errcheck ${FLAGS}  $(go list -f '{{.Dir}}' ./... | grep -v /tests/ | grep -v /docs/) ${IGNORE_COMMAND} $*" 2>&1)
	test -z "${OUTPUT}"
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	if [ "${SEND_COMMNET}" = "true" ]; then
		COMMENT="## ⚠ errcheck Failed
\`\`\`
${OUTPUT}
\`\`\`
"
	fi
}

# check_fmt is excute "go fmt" and generate ${COMMENT} and ${SUCCESS}
check_fmt() {
	set +e
	UNFMT_FILES=$(sh -c "gofmt -l -s . $*" 2>&1)
	test -z "${UNFMT_FILES}"
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	if [ "${SEND_COMMNET}" = "true" ]; then
		FMT_OUTPUT=""
		for file in ${UNFMT_FILES}; do
			FILE_DIFF=$(gofmt -d -e "${file}" | sed -n '/@@.*/,//{/@@.*/d;p}')
			FMT_OUTPUT="${FMT_OUTPUT}
<details><summary><code>${file}</code></summary>

\`\`\`diff
${FILE_DIFF}
\`\`\`
</details>

"
		done
		COMMENT="## ⚠ gofmt Failed
${FMT_OUTPUT}
"
	fi
}

# check_imports is excute go imports and generate ${COMMENT} and ${SUCCESS}
check_imports() {
	set +e
	UNFMT_FILES=$(sh -c "goimports -l . $*" 2>&1)
	test -z "${UNFMT_FILES}"
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	if [ "${SEND_COMMNET}" = "true" ]; then
		FMT_OUTPUT=""
		for file in ${UNFMT_FILES}; do
			FILE_DIFF=$(goimports -d -e "${file}" | sed -n '/@@.*/,//{/@@.*/d;p}')
			FMT_OUTPUT="${FMT_OUTPUT}
<details><summary><code>${file}</code></summary>

\`\`\`diff
${FILE_DIFF}
\`\`\`
</details>

"
		done
		COMMENT="## ⚠ goimports Failed
${FMT_OUTPUT}
"
	fi

}

# check_lint is excute golint and generate ${COMMENT} and ${SUCCESS}
check_lint() {
	set +e

	echo $PWD
	pwd
	ls -la
	# exclude tests folder by default
	OUTPUT=$(sh -c "golint -set_exit_status  $(go list -f '{{.Dir}}' ./... | grep -v /tests/ | grep -v /docs/) $*" 2>&1)
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	if [ "${SEND_COMMNET}" = "true" ]; then
		COMMENT="## ⚠ golint Failed
$(echo "${OUTPUT}" | awk 'END{print}')
<details><summary>Show Detail</summary>

\`\`\`
$(echo "${OUTPUT}" | sed -e '$d')
\`\`\`
</details>
"
	fi
}

# check_sec is excute gosec and generate ${COMMENT} and ${SUCCESS}
check_sec() {
	set +e
	# exclude tests folder by default
	gosec -out result.txt ${FLAGS}  $(go list -f '{{.Dir}}' ./... | grep -v /tests/ | grep -v /docs/)
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	if [ "${SEND_COMMNET}" = "true" ]; then
		COMMENT="## ⚠ gosec Failed
\`\`\`
$(tail -n 6 result.txt)
\`\`\`
<details><summary>Show Detail</summary>

\`\`\`
$(cat result.txt)
\`\`\`
[Code Reference](https://github.com/securego/gosec#available-rules)

</details>
"
	fi
}

# check_shadow is excute "go vet -vettool=/go/bin/shadow" and generate ${COMMENT} and ${SUCCESS}
check_shadow() {
	set +e
	# exclude tests folder by default
	OUTPUT=$(sh -c "go vet -vettool=/go/bin/shadow ${FLAGS}  $(go list -f '{{.Dir}}' ./... | grep -v /tests/ | grep -v /docs/) $*" 2>&1)
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	if [ "${SEND_COMMNET}" = "true" ]; then
		COMMENT="## ⚠ shadow Failed
\`\`\`
${OUTPUT}
\`\`\`
"
	fi
}

# check_staticcheck is excute "staticcheck" and generate ${COMMENT} and ${SUCCESS}
check_staticcheck() {
	set +e
	# exclude tests folder by default
	OUTPUT=$(sh -c "staticcheck ${FLAGS}  $(go list -f '{{.Dir}}' ./... | grep -v /tests/ | grep -v /docs/) $*" 2>&1)
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	if [ "${SEND_COMMNET}" = "true" ]; then
		COMMENT="## ⚠ staticcheck Failed
\`\`\`
${OUTPUT}
\`\`\`

[Checks Document](https://staticcheck.io/docs/checks)
"
	fi
}

# check_vet is excute "go vet" and generate ${COMMENT} and ${SUCCESS}
check_vet() {
	set +e
	# exclude tests folder by default
	OUTPUT=$(sh -c "go vet ${FLAGS}  $(go list -f '{{.Dir}}' ./... | grep -v /tests/ | grep -v /docs/) $*" 2>&1)
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	if [ "${SEND_COMMNET}" = "true" ]; then
		COMMENT="## ⚠ vet Failed
\`\`\`
${OUTPUT}
\`\`\`
"
	fi
}

# check_misspelling is excute "misspell" and generate ${COMMENT} and ${SUCCESS}
check_misspelling() {
	set +e
	# exclude tests folder by default
	OUTPUT=$(sh -c "misspell ${FLAGS} -error . $*" 2>&1)
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	if [ "${SEND_COMMNET}" = "true" ]; then
		COMMENT="## ⚠ misspell Failed
\`\`\`
${OUTPUT}
\`\`\`
"
	fi
}

# check_ineffassign is excute "ineffassign" and generate ${COMMENT} and ${SUCCESS}
check_ineffassign() {
	set +e
	# exclude tests folder by default
	OUTPUT=$(sh -c "ineffassign  $(go list -f '{{.Dir}}' ./... | grep -v /tests/ | grep -v /docs/) $*" 2>&1)
	SUCCESS=$?

	set -e
	if [ ${SUCCESS} -eq 0 ]; then
		return
	fi

	if [ "${SEND_COMMNET}" = "true" ]; then
		COMMENT="## ⚠ ineffassign Failed
\`\`\`
${OUTPUT}
\`\`\`
"
	fi
}


# ------------------------
#  Main Flow
# ------------------------
cd ${GITHUB_WORKSPACE}/${WORKING_DIR}

case ${RUN} in
	"errcheck" )
		mod_download
		check_errcheck
		;;
	"fmt" )
		check_fmt
		;;
	"imports" )
		check_imports
		;;
	"lint" )
		check_lint
		;;
	"sec" )
		mod_download
		check_sec
		;;
	"shadow" )
		mod_download
		check_shadow
		;;
	"staticcheck" )
		mod_download
		check_staticcheck
		;;
	"vet" )
		mod_download
		check_vet
		;;
	"misspell" )
		mod_download
		check_misspelling
		;;
	"ineffassign" )
		mod_download
		check_ineffassign
		;;
	* )
		echo "Invalid command"
		exit 1

esac

if [ ${SUCCESS} -ne 0 ]; then
	echo "Check Failed!!"
	echo ${COMMENT}
	if [ "${SEND_COMMNET}" = "true" ]; then
		send_comment
	fi
fi

exit ${SUCCESS}

