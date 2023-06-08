#!/bin/bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

SESSION_DIR="${SCRIPT_DIR}/fhir_mobile_pact_session"

[[ ! -d $SESSION_DIR ]] && mkdir "$SESSION_DIR"

URL_ROOT="https://localhost"

function urldecode() {
  : "${*//+/ }"
  echo -e "${_//%/\\x}"
}

function paginated_get_curl() {
  local message=$1
  local page=1
  local url=$2
  local token=$4
  local filename
  echo -n "${message}"
  while
    filename="${SESSION_DIR}/$3_page${page}.json"
    echo -n " page ${page}"
    curl -ksX GET "${url}" \
      -H "Authorization: Bearer ${token}" \
      -H "accept: application/json" \
      -H "Content-Type: application/json" \
      -o "${filename}" >/dev/null
    if grep -q '"relation":' "${filename}"; then
      url=$(urldecode "$(jq -r '.link[] | select(.relation == "next") | .url' "${filename}")" | sed -e "s/demo\.openimis\.org/localhost/" -e "s/https:/http:/")
    else
      echo " ERROR"
      return 1
    fi
    [[ -n $url ]]
  do
    ((page++))
  done
  echo
}

# Test if the backend is reachable/available
echo -n "Check that the server is up (5 tries):"
try=0
success=0
while
  if curl -ksI "${URL_ROOT}/api/" | grep 404 >/dev/null; then
    success=1
  else
    ((try++))
  fi
  [[ $success -eq 0 ]] && [[ try -lt 5 ]]
do
  echo -n " ${try}"
  sleep 5
done
echo " UP!"
[[ $success -eq 0 ]] && {
  echo "Backend is not reachable at localhost:80."
  echo "Please check that it is properly running with \`./run.sh status\`. You"
  echo "can run it with \`./run.sh server\`."
  exit 1
}

# login and retrieve JWT
echo "login"
# curl -ksX POST "${URL_ROOT}/api/graphql" \
#   -H "accept: application/json" \
#   -H "Content-Type: application/json" \
#   -c "${COOKIE_FILE}" \
#   -d @"${SCRIPT_DIR}/fhir_mobile_pact_files/authenticate.json.graphql"

token=$(
  curl -ksX POST "${URL_ROOT}/api/api_fhir_r4/login/" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -d @"${SCRIPT_DIR}/fhir_mobile_pact_files/authenticate.json" | jq -r '.token'
)

# nothin similar to `claim/Controls`

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1389592716/FHIR+R4+-+Practitioner
# similar to `claim/GetClaimAdmins` (not directly used in claim mobile app)
paginated_get_curl "get practitioners (claim admins)" \
  "${URL_ROOT}/api/api_fhir_r4/Practitioner/" \
  "claim_admins" "${token}"

# https://fhir.openimis.org/CodeSystem-diagnosis-ICD10-level1.html
# similar to a part of `claim/GetDiagnosesServicesItems`
echo "get code systems"
curl -ksX GET "${URL_ROOT}/api/api_fhir_r4/CodeSystem/diagnosis/" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${token}" \
  -o "${SESSION_DIR}/claim_dianosis.json" >/dev/null

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1400012844/FHIR+R4+-+ActivityDefinition
# similar to a part of `claim/GetDiagnosesServicesItems` and partly
# `claim/GetPaymentLists`

paginated_get_curl "get services (diagnoses services items and payment list)" \
  "${URL_ROOT}/api/api_fhir_r4/ActivityDefinition/" \
  "claim_services" "${token}"

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1400045588/FHIR+R4+-+Medication
# similar to a part of `claim/GetDiagnosesServicesItems` and partly
# `claim/GetPaymentLists`

paginated_get_curl "get medications (diagnoses services items and payment list):" \
  "${URL_ROOT}/api/api_fhir_r4/Medication/" \
  "claim_medications" "${token}"

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1389592652/FHIR+R4+-+ClaimResponse
# similar to `${URL_ROOT}/api/claim/GetClaims` list or get on a given id

paginated_get_curl "get claims:" \
  "${URL_ROOT}/api/api_fhir_r4/ClaimResponse/" \
  "claim_responses" "${token}"

# https://www.hl7.org/fhir/organization.html
# to retrieve health facilities (not directly used in claim mobile app)

paginated_get_curl "get organizations (health facilities):" \
  "${URL_ROOT}/api/api_fhir_r4/Organization/" \
  "claim_organizations" "${token}"

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1389592724/FHIR+R4+-+PractitionerRole
# Neeeded to link practitioner to their organization
paginated_get_curl "get practitioner roles" \
  "${URL_ROOT}/api/api_fhir_r4/PractitionerRole/" \
  "claim_pracitioner_roles" "${token}"

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1389133931/FHIR+R4+-+Patient
# similar to `insuree/{chfid}` but list or direct ID

echo "get patients (insuree)"
curl -ksX GET "${URL_ROOT}/api/api_fhir_r4/Patient/" \
  -H "Authorization: Bearer ${token}" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -o "${SESSION_DIR}/claim_patients.json" >/dev/null

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1389297783/FHIR+R4+-+Coverage
# similar to `insuree/{chfid}/enquire` but list or direct ID

echo "get coverages (enquire)"
curl -ksX GET "${URL_ROOT}/api/api_fhir_r4/Coverage/" \
  -H "Authorization: Bearer ${token}" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -o "${SESSION_DIR}/claim_coverages.json" >/dev/null
