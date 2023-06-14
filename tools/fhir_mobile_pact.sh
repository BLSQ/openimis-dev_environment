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

curl -ksX POST "${URL_ROOT}/api/graphql" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -d @"${SCRIPT_DIR}/fhir_mobile_pact_files/authenticate-graphql.json" &>/dev/null

token=$(
  curl -ksX POST "${URL_ROOT}/api/api_fhir_r4/login/" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -d @"${SCRIPT_DIR}/fhir_mobile_pact_files/authenticate.json" | jq -r '.token'
)

[[ -z $token ]] && {
  echo "Login Failed. Either the Django bakcend service hasn't yet completely"
  echo "boot up or there is something wrong. Please check the status of your"
  echo "environment with \`./run.sh status\`. If everything is ok, check the"
  echo "log of the backend with \`./run.sh logs\` (if you add the option \`-f\`"
  echo "it'll stream the log in the stdout). It is ready when you see the"
  echo "following line: \"daphne.server: Listening on TCP address 0.0.0.0:8000\"."
  exit 1
}

# nothing similar to `claim/Controls`

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1389592716/FHIR+R4+-+Practitioner
# similar to `claim/GetClaimAdmins` (not directly used in claim mobile app)
paginated_get_curl "get practitioners (claim admins)" \
  "${URL_ROOT}/api/api_fhir_r4/Practitioner/?resourceType=ca" \
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
  "${URL_ROOT}/api/api_fhir_r4/ActivityDefinition/?_lastUpdated=lt2023-06-13T00:00:00" \
  "claim_services" "${token}"

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1400045588/FHIR+R4+-+Medication
# similar to a part of `claim/GetDiagnosesServicesItems` and partly
# `claim/GetPaymentLists`

paginated_get_curl "get medications (diagnoses services items and payment list):" \
  "${URL_ROOT}/api/api_fhir_r4/Medication/?_lastUpdated=lt2023-06-13T00:00:00" \
  "claim_medications" "${token}"

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1389592652/FHIR+R4+-+ClaimResponse
# similar to `${URL_ROOT}/api/claim/GetClaims` list or get on a given id

paginated_get_curl "get claim responses:" \
  "${URL_ROOT}/api/api_fhir_r4/ClaimResponse/?_lastUpdated=lt2023-06-13T00:00:00" \
  "claim_responses" "${token}"

paginated_get_curl "get claims:" \
  "${URL_ROOT}/api/api_fhir_r4/Claim/?_lastUpdated=lt2023-06-13T00:00:00&refDate=2019-04-22&contained=True" \
  "claim" "${token}"

# "${URL_ROOT}/api/api_fhir_r4/Claim/E84A3FCE-9BC2-4968-A2D2-BCFAE03B0430/" \
# "${URL_ROOT}/api/api_fhir_r4/Claim/?patient=CAAA21A5-42A3-4BC0-9DA2-E7951B283307" \

# https://www.hl7.org/fhir/organization.html
# to retrieve health facilities (not directly used in claim mobile app)

paginated_get_curl "get organizations (health facilities):" \
  "${URL_ROOT}/api/api_fhir_r4/Organization/" \
  "claim_organizations" "${token}"

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1389592724/FHIR+R4+-+PractitionerRole
# Neeeded to link practitioner to their organization
paginated_get_curl "get practitioner roles" \
  "${URL_ROOT}/api/api_fhir_r4/PractitionerRole/" \
  "claim_practitioner_roles" "${token}"

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1389133931/FHIR+R4+-+Patient
# similar to `insuree/{chfid}` but list or direct ID

paginated_get_curl "get patients (insuree)" \
  "${URL_ROOT}/api/api_fhir_r4/Patient/" \
  "patients" "${token}"

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1389297783/FHIR+R4+-+Coverage
# part of `insuree/{chfid}/enquire` but list

paginated_get_curl "get coverages (enquire)" \
  "${URL_ROOT}/api/api_fhir_r4/Coverage/" \
  "claim_coverages" "${token}"

# https://openimis.atlassian.net/wiki/spaces/OP/pages/1814822920/FHIR+R4+Contract
# part of `insuree/{chfid}/enquire` but list
paginated_get_curl "get contracts (enquire)" \
  "${URL_ROOT}/api/api_fhir_r4/Contract/" \
  "claim_contracts" "${token}"
