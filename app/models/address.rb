class Address < ApplicationRecord
  belongs_to :user

  attribute :address_line_1
  attribute :address_line_2
  attribute :city
  attribute :province
  attribute :postal_code
  attribute :country

  enum :country, {
    "US - United States": "US - United States",
    "CA - Canada": "CA - Canada",
    "GB - United Kingdom": "GB - United Kingdom",
    "MX - Mexico": "MX - Mexico",
    "BR - Brazil": "BR - Brazil",
    "AR - Argentina": "AR - Argentina",
    "CL - Chile": "CL - Chile",
    "CO - Colombia": "CO - Colombia",
    "PE - Peru": "PE - Peru",
    "DE - Germany": "DE - Germany",
    "FR - France": "FR - France",
    "ES - Spain": "ES - Spain",
    "IT - Italy": "IT - Italy",
    "PT - Portugal": "PT - Portugal",
    "NL - Netherlands": "NL - Netherlands",
    "BE - Belgium": "BE - Belgium",
    "CH - Switzerland": "CH - Switzerland",
    "AT - Austria": "AT - Austria",
    "SE - Sweden": "SE - Sweden",
    "NO - Norway": "NO - Norway",
    "DK - Denmark": "DK - Denmark",
    "FI - Finland": "FI - Finland",
    "IE - Ireland": "IE - Ireland",
    "PL - Poland": "PL - Poland",
    "CZ - Czech Republic": "CZ - Czech Republic",
    "RU - Russia": "RU - Russia",
    "UA - Ukraine": "UA - Ukraine",
    "CN - China": "CN - China",
    "JP - Japan": "JP - Japan",
    "KR - South Korea": "KR - South Korea",
    "IN - India": "IN - India",
    "AU - Australia": "AU - Australia",
    "NZ - New Zealand": "NZ - New Zealand",
    "ZA - South Africa": "ZA - South Africa",
    "NG - Nigeria": "NG - Nigeria",
    "EG - Egypt": "EG - Egypt",
    "AE - United Arab Emirates": "AE - United Arab Emirates",
    "SA - Saudi Arabia": "SA - Saudi Arabia",
    "IL - Israel": "IL - Israel",
    "TR - Turkey": "TR - Turkey",
    "TH - Thailand": "TH - Thailand",
    "VN - Vietnam": "VN - Vietnam",
    "PH - Philippines": "PH - Philippines",
    "ID - Indonesia": "ID - Indonesia",
    "MY - Malaysia": "MY - Malaysia",
    "SG - Singapore": "SG - Singapore"
  }
end
