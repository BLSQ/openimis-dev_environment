
# Difference between C# REST API and FHIR API

## Context

This is based on the default DB provisioning (full demo). It can be reproduced
with the script `cs_rest_api_mobile_pact.sh` and `fhir_mobile_pact.sh` that
you can find in the project [openimis-dev_environment](https://gitlab.com/toch/openimis-dev_environment).

## Authentication

### C# REST API

It's a POST HTTP request at `/rest/api/login` with:

```json
{
    "userName": "<USERNAME>",
    "password": "<PASSWORD"
}
```

In return, you receive the JWT in a JSON HTTP response:

```json
{
    "access_token": "<TOKEN>",
    "expires_on": "2023-05-22T12:46:58.2876845+00:00"
}
```

The token is then passed in the following HTTP header
`Authorization: Bearer <token>` to HTTP request protected endpoints.

### FHIR API

It's a POST HTTP request at `/api/graphql` with:

```json
{
    "query": "mutation authenticate($username: String!, $password: String!) {tokenAuth(username: $username, password: $password) {refreshExpiresIn}}",
    "variables":
    {
        "username": "<USERNAME>",
        "password": "<PASSWORD"
    }
}
```

In return, you receive the JWT in a cookie with `JWT-refresh-token` and `JWT`.
The session is then saved in the cookie, and the cookie has to be used to
HTTP request protected endpoints, including the FHIR ones.

## Claim administrators / Practitioners

### C# REST API

It's a GET HTTP request at `/rest/api/claim/GetClaimAdmins`. It returns a JSON payload
that contains the list of administrators:

```json
{
    "error_occured": false,
    "claim_admins":
    [
        {
            "lastName": "Rushila",
            "otherNames": "Dani",
            "claimAdminCode": "JMDP0011",
            "hfCode": "JMDP001"
        }
    ]
}
```

### FHIR API

It's a GET HTTP request at `/api/api_fhir_r4/Practitioner/`. It returns a list
of practitioners, including the claim administrators:

```json
{
    "resourceType": "Bundle",
    "type": "searchset",
    "total": 29,
    "link":
    [
        {
            "relation": "self",
            "url": "https%3A%2F%2Fdemo.openimis.org%2Fapi%2Fapi_fhir_r4%2FPractitioner%2F"
        },
        {
            "relation": "next",
            "url": "https%3A%2F%2Fdemo.openimis.org%2Fapi%2Fapi_fhir_r4%2FPractitioner%2F%3Fpage-offset%3D2"
        }
    ],
    "entry":
    [
        {
            "fullUrl": "https://demo.openimis.org/api/api_fhir_r4/Practitioner/16F01D1E-2814-4676-BE06-9AEAD8B40922",
            "resource":
            {
                "resourceType": "Practitioner",
                "id": "16F01D1E-2814-4676-BE06-9AEAD8B40922",
                "identifier":
                [
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "UUID"
                                }
                            ]
                        },
                        "value": "16F01D1E-2814-4676-BE06-9AEAD8B40922"
                    },
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "Code"
                                }
                            ]
                        },
                        "value": "JMDP0011"
                    }
                ],
                "name":
                [
                    {
                        "use": "usual",
                        "family": "Rushila",
                        "given":
                        [
                            "Dani"
                        ]
                    }
                ],
                "birthDate": "1979-10-09",
                "qualification":
                [
                    {
                        "code":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/practitioner-qualification-type",
                                    "code": "CA",
                                    "display": "Claim Administrator"
                                }
                            ]
                        }
                    }
                ]
            }
        }
    ]
}
```

#### References

* [Wiki](https://openimis.atlassian.net/wiki/spaces/OP/pages/1389592716/FHIR+R4+-+Practitioner)
* [FHIR Doc](https://fhir.openimis.org/StructureDefinition-openimis-claim-administrator-practitioner.html)

### Mapping

We can do the following mapping:

| C# REST API | FHIR API |
| ----------- | -------- |
| `.claim_admins[0].lastName` | `.entry[0].resource.name[0].family` |
| `.claim_admins[0].otherNames` | `.entry[0].resource.name[0].given` |
| `.claim_admins[0].claimAdminCode` | `.entry[0].resource.identifier[] | select(.type.coding[].code == "Code") | .value` |
| `.claim_admins[0].hfCode` | Not Found |

## Controls

### C# REST API

It's a GET HTTP request at `/claim/Controls`. It returns a JSON payload
that contains the list of form fields and their visibility and presence property
(i.e. optional, mandatory, required, hidden):

```json
{
    "error_occured": false,
    "controls":
    [
        {
            "fieldName": "Age",
            "adjustibility": "M",
            "usage": "Search Insurance Number/Enquiry"
        }
    ]
}
```

### FHIR API

None

### Mapping

It seems there isn't any correspondence in the FHIR API, as such there isn't
any mapping.

## Diagnoses, Items, and Services

### C# REST API

It's a POST HTTP request at `/rest/api/claim/GetDiagnosesServicesItems` with:

```json
{
    "last_update_date": "2000-01-01"
}
```

It return a JSON payload that contains the list of diagnoses, services, and
items:

```json
{
    "diagnoses":
    [
        {
            "code": "A00",
            "name": "Cholera"
        }
    ],
    "services":
    [
        {
            "code": "M1",
            "name": "OBG Cervical Cerclage - Shrodikar",
            "price": "21000.00"
        }
    ],
    "items":
    [
        {
            "code": "0001",
            "name": "ACETYLSALICYLIC ACID (ASPIRIN)  TABS 300MG",
            "price": "10.00"
        }
    ]
}
```

### FHIR API

There are 3 GET HTTP requests: 
1. `/api/api_fhir_r4/ActivityDefinition/` returns the list of services,
2. `/api/api_fhir_r4/CodeSystem/diagnosis/` returns the list of diagnosis code,
   and
3. `/api/api_fhir_r4/Medications/` returns the list of items,


#### Services or Activity Definitions

```json
{
    "resourceType": "Bundle",
    "type": "searchset",
    "total": 81,
    "link":
    [
        {
            "relation": "self",
            "url": "https%3A%2F%2Fdemo.openimis.org%2Fapi%2Fapi_fhir_r4%2FActivityDefinition%2F"
        },
        {
            "relation": "next",
            "url": "https%3A%2F%2Fdemo.openimis.org%2Fapi%2Fapi_fhir_r4%2FActivityDefinition%2F%3Fpage-offset%3D2"
        }
    ],
    "entry":
    [
        {
            "fullUrl": "https://demo.openimis.org/api/api_fhir_r4/ActivityDefinition/FC7AB64C-033E-45D3-839E-DB1E4B93611F",
            "resource":
            {
                "resourceType": "ActivityDefinition",
                "id": "FC7AB64C-033E-45D3-839E-DB1E4B93611F",
                "extension":
                [
                    {
                        "url": "https://openimis.github.io/openimis_fhir_r4_ig/StructureDefinition/unit-price",
                        "valueMoney":
                        {
                            "value": 21000.0,
                            "currency": "$"
                        }
                    },
                    {
                        "url": "https://openimis.github.io/openimis_fhir_r4_ig/StructureDefinition/activity-definition-level",
                        "valueCodeableConcept":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/ValueSet/activity-definition-level",
                                    "code": "D",
                                    "display": "Day of stay"
                                }
                            ],
                            "text": "Day of stay"
                        }
                    }
                ],
                "identifier":
                [
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "UUID"
                                }
                            ]
                        },
                        "value": "FC7AB64C-033E-45D3-839E-DB1E4B93611F"
                    },
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "Code"
                                }
                            ]
                        },
                        "value": "M1"
                    }
                ],
                "name": "M1",
                "title": "OBG Cervical Cerclage - Shrodikar",
                "status": "active",
                "date": "2017-01-01T00:00:00",
                "useContext":
                [
                    {
                        "code":
                        {
                            "system": "http://terminology.hl7.org/CodeSystem/usage-context-type",
                            "code": "gender",
                            "display": "Gender"
                        },
                        "valueCodeableConcept":
                        {
                            "coding":
                            [
                                {
                                    "system": "http://hl7.org/fhir/administrative-gender",
                                    "code": "female",
                                    "display": "Female"
                                }
                            ],
                            "text": "Female"
                        }
                    },
                    {
                        "code":
                        {
                            "system": "http://terminology.hl7.org/CodeSystem/usage-context-type",
                            "code": "age",
                            "display": "Age Range"
                        },
                        "valueCodeableConcept":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/usage-context-age-type",
                                    "code": "adult",
                                    "display": "Adult"
                                },
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/usage-context-age-type",
                                    "code": "child",
                                    "display": "Child"
                                }
                            ],
                            "text": "Adult or Child"
                        }
                    },
                    {
                        "code":
                        {
                            "system": "http://terminology.hl7.org/CodeSystem/usage-context-type",
                            "code": "workflow",
                            "display": "Workflow Setting"
                        },
                        "valueCodeableConcept":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/activity-definition-usage-context-workflow-type",
                                    "code": "S",
                                    "display": "Surgery"
                                }
                            ],
                            "text": "Surgery"
                        }
                    },
                    {
                        "code":
                        {
                            "system": "http://terminology.hl7.org/CodeSystem/usage-context-type",
                            "code": "venue",
                            "display": "Clinical Venue"
                        },
                        "valueCodeableConcept":
                        {
                            "coding":
                            [
                                {
                                    "system": "http://terminology.hl7.org/2.1.0/CodeSystem-v3-ActCode.html",
                                    "code": "AMB",
                                    "display": "ambulatory"
                                },
                                {
                                    "system": "http://terminology.hl7.org/2.1.0/CodeSystem-v3-ActCode.html",
                                    "code": "IMP",
                                    "display": "IMP"
                                }
                            ],
                            "text": "ambulatory or IMP"
                        }
                    }
                ],
                "topic":
                [
                    {
                        "coding":
                        [
                            {
                                "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/activity-definition-service-type.html",
                                "code": "C",
                                "display": "Curative"
                            }
                        ]
                    }
                ],
                "timingTiming":
                {
                    "repeat":
                    {
                        "frequency": 1,
                        "period": 0.0,
                        "periodUnit": "d"
                    }
                }
            }
        }
    ]
}

```

#### Diagnosis

```json
{
    "resourceType": "CodeSystem",
    "id": "diagnosis-ICD10-level1",
    "url": "https://demo.openimis.org/api/api_fhir_r4/CodeSystem/diagnosis/",
    "name": "DiagnosisICD10Level1CS",
    "title": "ICD 10 Level 1 diagnosis (Claim)",
    "status": "active",
    "date": "2023-05-19T08:04:59.574280",
    "description": "The actual list of diagnosis configured in openIMIS.",
    "content": "complete",
    "count": 1910,
    "concept":
    [
        {
            "code": "A00",
            "display": "Cholera"
        },
        {
            "code": "A01",
            "display": "Typhoid and paratyphoid fevers"
        }
    ]
}
```

#### Items or Medications

```json
{
    "resourceType": "Bundle",
    "type": "searchset",
    "total": 257,
    "link":
    [
        {
            "relation": "self",
            "url": "https%3A%2F%2Fdemo.openimis.org%2Fapi%2Fapi_fhir_r4%2FMedication%2F"
        },
        {
            "relation": "next",
            "url": "https%3A%2F%2Fdemo.openimis.org%2Fapi%2Fapi_fhir_r4%2FMedication%2F%3Fpage-offset%3D2"
        }
    ],
    "entry":
    [
        {
            "fullUrl": "https://demo.openimis.org/api/api_fhir_r4/Medication/995CA442-FC47-4F1F-9277-9163932ABB78",
            "resource":
            {
                "resourceType": "Medication",
                "id": "995CA442-FC47-4F1F-9277-9163932ABB78",
                "extension":
                [
                    {
                        "url": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/unit-price",
                        "valueMoney":
                        {
                            "value": 10.0,
                            "currency": "$"
                        }
                    },
                    {
                        "url": "https://openimis.github.io/openimis_fhir_r4_ig/StructureDefinition/medication-type",
                        "valueCodeableConcept":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/medication-item-type",
                                    "code": "D",
                                    "display": "Drug"
                                }
                            ]
                        }
                    },
                    {
                        "extension":
                        [
                            {
                                "url": "Gender",
                                "valueUsageContext":
                                {
                                    "code":
                                    {
                                        "system": "http://terminology.hl7.org/CodeSystem/usage-context-type",
                                        "code": "gender",
                                        "display": "Gender"
                                    },
                                    "valueCodeableConcept":
                                    {
                                        "coding":
                                        [
                                            {
                                                "system": "http://hl7.org/fhir/administrative-gender",
                                                "code": "male",
                                                "display": "Male"
                                            },
                                            {
                                                "system": "http://hl7.org/fhir/administrative-gender",
                                                "code": "female",
                                                "display": "Female"
                                            }
                                        ]
                                    }
                                }
                            },
                            {
                                "url": "Age",
                                "valueUsageContext":
                                {
                                    "code":
                                    {
                                        "system": "http://terminology.hl7.org/CodeSystem/usage-context-type",
                                        "code": "age",
                                        "display": "Age"
                                    },
                                    "valueCodeableConcept":
                                    {
                                        "coding":
                                        [
                                            {
                                                "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/usage-context-age-type",
                                                "code": "adult",
                                                "display": "Adult"
                                            },
                                            {
                                                "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/usage-context-age-type",
                                                "code": "child",
                                                "display": "Child"
                                            }
                                        ]
                                    }
                                }
                            },
                            {
                                "url": "CareType",
                                "valueUsageContext":
                                {
                                    "code":
                                    {
                                        "system": "http://terminology.hl7.org/CodeSystem/usage-context-type",
                                        "code": "venue",
                                        "display": "Clinical Venue"
                                    },
                                    "valueCodeableConcept":
                                    {
                                        "coding":
                                        [
                                            {
                                                "system": "http://terminology.hl7.org/CodeSystem/v3-ActCode",
                                                "code": "AMB",
                                                "display": "ambulatory"
                                            }
                                        ]
                                    }
                                }
                            }
                        ],
                        "url": "https://openimis.github.io/openimis_fhir_r4_ig/StructureDefinition/medication-usage-context"
                    },
                    {
                        "url": "https://openimis.github.io/openimis_fhir_r4_ig/StructureDefinition/medication-level",
                        "valueCodeableConcept":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/medication-level",
                                    "code": "M",
                                    "display": "Medication"
                                }
                            ],
                            "text": "Medication"
                        }
                    }
                ],
                "identifier":
                [
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "UUID"
                                }
                            ]
                        },
                        "value": "995CA442-FC47-4F1F-9277-9163932ABB78"
                    },
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "Code"
                                }
                            ]
                        },
                        "value": "0001"
                    }
                ],
                "code":
                {
                    "text": "ACETYLSALICYLIC ACID (ASPIRIN)  TABS 300MG"
                },
                "status": "active",
                "form":
                {
                    "text": "1000 TABLETS"
                },
                "amount":
                {
                    "numerator":
                    {
                        "value": 1000.0
                    }
                }
            }
        }
    ]
}
```

#### References

Wiki pages:

* [Medication](https://openimis.atlassian.net/wiki/spaces/OP/pages/1400045588/FHIR+R4+-+Medication)
* [Activity Definition](https://openimis.atlassian.net/wiki/spaces/OP/pages/1400012844/FHIR+R4+-+ActivityDefinition)

FHIR Doc:

* [Medication](https://fhir.openimis.org/StructureDefinition-openimis-medication.html)
* [Activity Definition](https://fhir.openimis.org/StructureDefinition-openimis-activitiy-definition.html)
* [Code System - Diagnosis](https://fhir.openimis.org/CodeSystem-diagnosis-ICD10-level1.html)

### Mapping

We can do the following mapping:

| C# REST API | FHIR API |
| ----------- | -------- |
| `.diagnoses[0].code` | Diagnosis - `.concept[0].code` |
| `.diagnoses[0].name` | Diagnosis - `.concept[0].display` |
| `.services[0].code` | ActivityDefinition - `.entry[0].resource.identifier[] | select(.type.coding[].code == "Code" ).value` |
| `.services[0].name` | ActivityDefinition - `.entry[0].title` |
| `.services[0].price` | ActivityDefinition - `.entry[0].resource.extension[] | select(.url | test("unit-price")).valueMoney.value` |
| `.items[0].code` | Medication - `.entry[0].resource.identifier[] | select(.type.coding[].code == "Code" ).value` |
| `.items[0].name` | Medication - `.entry[0].resource.code.text` |
| `.items[0].price` | Medication - `.entry[0].resource.extension[] | select(.url | test("unit-price")).valueMoney.value` |

## Payment List

### C# REST API

It's a POST HTTP request at `/rest/api/claim/GetClaimAdmins` with:
```json
{
    "claim_administrator_code": "VIHC0011",
    "last_update_date": "2000-01-01"
}
```

It returns a JSON payload:

```json
{
    "update_since_last": "2023-05-17T12:46:58.4881875Z",
    "health_facility_code": "VIHC001",
    "health_facility_name": "Juilöa Health Centre",
    "pricelist_services":
    [
        {
            "code": "A1",
            "name": "General Consultation",
            "price": "400.00"
        }
    ],
    "pricelist_items":
    [
        {
            "code": "0001",
            "name": "ACETYLSALICYLIC ACID (ASPIRIN)  TABS 300MG",
            "price": "10.00"
        }
    ]
}
```

### FHIR API

See above [Diagnoses, Items, and Services](#diagnoses-items-and-services).

There is also one GET HTTP request at `/api/api_fhir_r4/Organization/`. It returns the list of organizations (or health facilities):

```json
{
    "resourceType": "Bundle",
    "type": "searchset",
    "total": 16,
    "link":
    [
        {
            "relation": "self",
            "url": "https%3A%2F%2Fdemo.openimis.org%2Fapi%2Fapi_fhir_r4%2FOrganization%2F"
        },
        {
            "relation": "next",
            "url": "https%3A%2F%2Fdemo.openimis.org%2Fapi%2Fapi_fhir_r4%2FOrganization%2F%3Fpage-offset%3D2"
        }
    ],
    "entry":
    [
        {
            "fullUrl": "https://demo.openimis.org/api/api_fhir_r4/Organization/3134931E-945D-4A19-8166-13BA7B8D9F20",
            "resource":
            {
                "resourceType": "Organization",
                "id": "3134931E-945D-4A19-8166-13BA7B8D9F20",
                "extension":
                [
                    {
                        "url": "https://openimis.github.io/openimis_fhir_r4_ig/StructureDefinition/organization-legal-form",
                        "valueCodeableConcept":
                        {
                            "coding":
                            [
                                {
                                    "system": "CodeSystem/organization-legal-form",
                                    "code": "G",
                                    "display": "Government"
                                }
                            ]
                        }
                    },
                    {
                        "url": "https://openimis.github.io/openimis_fhir_r4_ig//StructureDefinition/organization-hf-level",
                        "valueCodeableConcept":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig//CodeSystem/organization-hf-level",
                                    "code": "C",
                                    "display": "Health Centre"
                                }
                            ]
                        }
                    },
                    {
                        "url": "https://openimis.github.io/openimis_fhir_r4_ig/StructureDefinition/organization-hf-care-type",
                        "valueCodeableConcept":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig//CodeSystem/organization-hf-care-type",
                                    "code": "O",
                                    "display": "Out-patient"
                                }
                            ]
                        }
                    }
                ],
                "identifier":
                [
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "UUID"
                                }
                            ]
                        },
                        "value": "3134931E-945D-4A19-8166-13BA7B8D9F20"
                    },
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "Code"
                                }
                            ]
                        },
                        "value": "VIHC001"
                    }
                ],
                "type":
                [
                    {
                        "coding":
                        [
                            {
                                "code": "prov"
                            }
                        ]
                    }
                ],
                "name": "Juilöa Health Centre",
                "address":
                [
                    {
                        "extension":
                        [
                            {
                                "url": "https://openimis.github.io/openimis_fhir_r4_ig//StructureDefinition/address-location-reference",
                                "valueReference":
                                {
                                    "reference": "Organization/3134931E-945D-4A19-8166-13BA7B8D9F20",
                                    "type": "Organization",
                                    "identifier":
                                    {
                                        "type":
                                        {
                                            "coding":
                                            [
                                                {
                                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                                    "code": "UUID"
                                                }
                                            ]
                                        },
                                        "value": "3134931E-945D-4A19-8166-13BA7B8D9F20"
                                    }
                                }
                            }
                        ],
                        "type": "physical",
                        "line":
                        [
                            "Guazn Health Centre"
                        ],
                        "district": "Vida",
                        "state": "Tahida"
                    }
                ],
                "contact":
                [
                    {
                        "purpose":
                        {
                            "coding":
                            [
                                {
                                    "system": "http://terminology.hl7.org/CodeSystem/contactentity-type",
                                    "code": "PAYOR"
                                }
                            ]
                        },
                        "name":
                        {
                            "use": "usual",
                            "family": "Louios",
                            "given":
                            [
                                "Ioulo"
                            ]
                        }
                    }
                ]
            }
        }
    ]
}
```

#### References

[FHIR Doc](https://openimis.atlassian.net/wiki/spaces/OP/pages/2330984456/FHIR+R4+-+Organisation)

### Mapping

When you can find the price for each service (Activity Definition) and each
item (Medication), and the details of a health facility (Organization), it
seems there isn't any way to retrieve a filtered list of services
(Activity Definition) and items (Medication) for a given health facility
(Organization)

## Claims (list)

### C# REST API

It's a POST HTTP request at `/rest/api/claim/GetClaims` with:

```json
{
    "claim_administrator_code": "VIHC0011",
    "status_claim": "Entered",
    "visit_date_from": "2000-01-01",
    "visit_date_to": "2023-05-08",
    "processed_date_from": "2000-01-01",
    "processed_date_to": "2023-05-08"
}
```

```json
{
    "error_occured": false,
    "data":
    [
        {
            "claim_uuid": "3aa4f381-d1b5-49aa-8872-08d5d06834f2",
            "health_facility_code": "VIHC001",
            "health_facility_name": "Juilöa Health Centre",
            "insurance_number": "105000002",
            "patient_name": "Ilina Doni",
            "main_dg": "Cholera",
            "claim_number": "CIB00001",
            "date_claimed": "2022-09-22",
            "visit_date_from": "2022-09-22",
            "visit_type": "Others",
            "claim_status": "Entered",
            "sec_dg_1": "Typhoid and paratyphoid fevers",
            "sec_dg_2": null,
            "sec_dg_3": null,
            "sec_dg_4": null,
            "visit_date_to": "2022-09-22",
            "claimed": 1000.0000,
            "approved": 1000.0000,
            "adjusted": 0.00,
            "explanation": "",
            "adjustment": null,
            "guarantee_number": "",
            "services":
            [
                {
                    "claim_uuid": "3aa4f381-d1b5-49aa-8872-08d5d06834f2",
                    "claim_number": "CIB00001",
                    "service": " BLOOD SLIDE FOR MALARIAL PARASITES (BS FOR MPS)",
                    "service_code": "I26",
                    "service_qty": 1.00,
                    "service_price": 800.00,
                    "service_adjusted_qty": null,
                    "service_adjusted_price": null,
                    "service_explination": "",
                    "service_justificaion": null,
                    "service_valuated": null,
                    "service_result": "0"
                }
            ],
            "items":
            [
                {
                    "claim_uuid": "3aa4f381-d1b5-49aa-8872-08d5d06834f2",
                    "claim_number": "CIB00001",
                    "item": "PARACETAMOL TABS 500 MG",
                    "item_code": "0182",
                    "item_qty": 20.00,
                    "item_price": 10.00,
                    "item_adjusted_qty": null,
                    "item_adjusted_price": null,
                    "item_explination": "",
                    "item_justificaion": null,
                    "item_valuated": null,
                    "item_result": "0"
                }
            ]
        }
    ]
}
```

### FHIR API

It's a GET HTTP request at `/api/api_fhir_r4/ClaimResponse/`. It returns a list
of claims:

```json
{
    "resourceType": "Bundle",
    "type": "searchset",
    "total": 11,
    "link":
    [
        {
            "relation": "self",
            "url": "https%3A%2F%2Fdemo.openimis.org%2Fapi%2Fapi_fhir_r4%2FClaimResponse%2F"
        },
        {
            "relation": "next",
            "url": "https%3A%2F%2Fdemo.openimis.org%2Fapi%2Fapi_fhir_r4%2FClaimResponse%2F%3Fpage-offset%3D2"
        }
    ],
    "entry":
    [
        {

            "fullUrl": "https://demo.openimis.org/api/api_fhir_r4/ClaimResponse/3AA4F381-D1B5-49AA-8872-08D5D06834F2",
            "resource":
            {
                "resourceType": "ClaimResponse",
                "id": "3AA4F381-D1B5-49AA-8872-08D5D06834F2",
                "identifier":
                [
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "UUID"
                                }
                            ]
                        },
                        "value": "3AA4F381-D1B5-49AA-8872-08D5D06834F2"
                    },
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "Code"
                                }
                            ]
                        },
                        "value": "CIB00001"
                    }
                ],
                "status": "active",
                "type":
                {
                    "coding":
                    [
                        {
                            "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/claim-visit-type",
                            "code": "O",
                            "display": "Other"
                        }
                    ]
                },
                "use": "claim",
                "patient":
                {
                    "reference": "Patient/1749F4F9-9B75-49E6-9894-2BA5F2B45C49",
                    "type": "Patient",
                    "identifier":
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "UUID"
                                }
                            ]
                        },
                        "value": "1749F4F9-9B75-49E6-9894-2BA5F2B45C49"
                    }
                },
                "created": "2023-05-19",
                "insurer":
                {
                    "reference": "openIMIS"
                },
                "requestor":
                {
                    "reference": "Practitioner/39D399C3-32A1-4CF7-9B2C-FC334567256C",
                    "type": "Practitioner",
                    "identifier":
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "UUID"
                                }
                            ]
                        },
                        "value": "39D399C3-32A1-4CF7-9B2C-FC334567256C"
                    }
                },
                "request":
                {
                    "reference": "ClaimV2/3AA4F381-D1B5-49AA-8872-08D5D06834F2",
                    "type": "ClaimV2",
                    "identifier":
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "UUID"
                                }
                            ]
                        },
                        "value": "3AA4F381-D1B5-49AA-8872-08D5D06834F2"
                    }
                },
                "outcome": "queued",
                "item":
                [
                    {
                        "extension":
                        [
                            {
                                "url": "https://openimis.github.io/openimis_fhir_r4_ig/StructureDefinition/claim-item-reference",
                                "valueReference":
                                {
                                    "reference": "Medication/10E8D40C-8C84-43A2-BC36-52C5F8197232",
                                    "type": "Medication",
                                    "identifier":
                                    {
                                        "type":
                                        {
                                            "coding":
                                            [
                                                {
                                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                                    "code": "UUID"
                                                }
                                            ]
                                        },
                                        "value": "10E8D40C-8C84-43A2-BC36-52C5F8197232"
                                    },
                                    "display": "0182"
                                }
                            }
                        ],
                        "itemSequence": 1,
                        "adjudication":
                        [
                            {
                                "category":
                                {
                                    "coding":
                                    [
                                        {
                                            "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/claim-status",
                                            "code": "2",
                                            "display": "entered"
                                        }
                                    ]
                                },
                                "reason":
                                {
                                    "coding":
                                    [
                                        {
                                            "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/claim-rejection-reasons",
                                            "code": "0",
                                            "display": "ACCEPTED"
                                        }
                                    ]
                                },
                                "amount":
                                {
                                    "value": 10.0,
                                    "currency": "$"
                                },
                                "value": 20.0
                            }
                        ]
                    },
                    {
                        "extension":
                        [
                            {
                                "url": "https://openimis.github.io/openimis_fhir_r4_ig/StructureDefinition/claim-item-reference",
                                "valueReference":
                                {
                                    "reference": "ActivityDefinition/5D392BD5-2A26-4AE8-87F6-96499CCADAD9",
                                    "type": "ActivityDefinition",
                                    "identifier":
                                    {
                                        "type":
                                        {
                                            "coding":
                                            [
                                                {
                                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                                    "code": "UUID"
                                                }
                                            ]
                                        },
                                        "value": "5D392BD5-2A26-4AE8-87F6-96499CCADAD9"
                                    },
                                    "display": "I26"
                                }
                            }
                        ],
                        "itemSequence": 2,
                        "adjudication":
                        [
                            {
                                "category":
                                {
                                    "coding":
                                    [
                                        {
                                            "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/claim-status",
                                            "code": "2",
                                            "display": "entered"
                                        }
                                    ]
                                },
                                "reason":
                                {
                                    "coding":
                                    [
                                        {
                                            "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/claim-rejection-reasons",
                                            "code": "0",
                                            "display": "ACCEPTED"
                                        }
                                    ]
                                },
                                "amount":
                                {
                                    "value": 800.0,
                                    "currency": "$"
                                },
                                "value": 1.0
                            }
                        ]
                    }
                ],
                "total":
                [
                    {
                        "category":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/claim-status",
                                    "code": "2",
                                    "display": "entered"
                                }
                            ]
                        },
                        "amount":
                        {
                            "value": 1000.0,
                            "currency": "$"
                        }
                    }
                ]
            }
        
        }
    ]
}
```

### Mapping

We can do the following mapping:

| C# REST API | FHIR API |
| ----------- | -------- |
| `.data[0].claim_uuid` | `.entry[0].resource.id` |
| `.data[0].health_facility_code` | None (maybe through the practitioner) |
| `.data[0].health_facility_name` | None (maybe through the practitioner) |
| `.data[0].insurance_number` | None (maybe through patient link `.entry[0].resource.patient.reference`) |
| `.data[0].patient_name` | None (maybe through patient link `.entry[0].resource.patient.reference`) |
| `.data[0].main_dg` | None |
| `.data[0].claim_number` | `.entry[0].resource.identifer[] | select(.type.coding[].code == "Code").value` |
| `.data[0].date_claimed` | None |
| `.data[0].visit_date_from` | None |
| `.data[0].visit_type` | `.entry[0].resource.type.coding[0].display` |
| `.data[0].claim_status` | None |
| `.data[0].sec_dg_1` | None |
| `.data[0].sec_dg_2` | None |
| `.data[0].sec_dg_3` | None |
| `.data[0].sec_dg_4` | None |
| `.data[0].visit_date_to` | None |
| `.data[0].claimed` | `.entry[0].total[] | select(.category.coding[].display == "entered").amount.value` |
| `.data[0].approved` | None (it seems it's done per item |
| `.data[0].adjusted` | None |
| `.data[0].explanation` | None |
| `.data[0].adjustement` | None |
| `.data[0].guarantee_number` | None |
| `.data[0].services` | `.entry[0].item[] | select(.extension[].valueReference.display == "I26")` |
| | the link with the service is done via the Activity Definition `.reference` |
| | the quantity, price, and status can be found in `.adjudication` |
| `.data[0].items` | `.entry[0].item[] | select(.extension[].valueReference.display == "0182")` |
| | the link with the service is done via the Medication `.reference` |
| | the quantity, price, and status can be found in `.adjudication` |

However, we get the all list of claims. It's not known if it's possible to
filter it for a given claim administrator (Practitioner) or health facility
(Organization).

Considering PractitionerRole (see below), it is possible to do the link and
filter it at the client side. Now the module might filter it based on the
authenticated user. This is something to check.

#### PractitionerRole (FHIR API)

It's a GET request at `/api/api_fhir_r4/PractitionerRole/`. It returns the following json payload:

```json
{
    "resourceType": "Bundle",
    "type": "searchset",
    "total": 29,
    "link":
    [
        {
            "relation": "self",
            "url": "https%3A%2F%2Fdemo.openimis.org%2Fapi%2Fapi_fhir_r4%2FPractitionerRole%2F"
        },
        {
            "relation": "next",
            "url": "https%3A%2F%2Fdemo.openimis.org%2Fapi%2Fapi_fhir_r4%2FPractitionerRole%2F%3Fpage-offset%3D2"
        }
    ],
    "entry":
    [
        {
            "fullUrl": "https://demo.openimis.org/api/api_fhir_r4/PractitionerRole/BA1FB395-292E-42CB-AE3A-349293C949A3",
            "resource":
            {
                "resourceType": "PractitionerRole",
                "id": "BA1FB395-292E-42CB-AE3A-349293C949A3",
                "identifier":
                [
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "UUID"
                                }
                            ]
                        },
                        "value": "BA1FB395-292E-42CB-AE3A-349293C949A3"
                    },
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "Code"
                                }
                            ]
                        },
                        "value": "JHOS0011"
                    }
                ],
                "practitioner":
                {
                    "reference": "Practitioner/BA1FB395-292E-42CB-AE3A-349293C949A3",
                    "type": "Practitioner",
                    "identifier":
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "UUID"
                                }
                            ]
                        },
                        "value": "BA1FB395-292E-42CB-AE3A-349293C949A3"
                    }
                },
                "organization":
                {
                    "reference": "Organization/A0544680-7438-440D-977D-61E85A1B0765",
                    "type": "Organization",
                    "identifier":
                    {
                        "type":
                        {
                            "coding":
                            [
                                {
                                    "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/openimis-identifiers",
                                    "code": "UUID"
                                }
                            ]
                        },
                        "value": "A0544680-7438-440D-977D-61E85A1B0765"
                    }
                },
                "code":
                [
                    {
                        "coding":
                        [
                            {
                                "system": "https://openimis.github.io/openimis_fhir_r4_ig/CodeSystem/practitioner-qualification-type",
                                "code": "CA",
                                "display": "Claim Administrator"
                            }
                        ]
                    }
                ]
            }
        },
    ]
}
```