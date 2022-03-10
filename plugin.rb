# frozen_string_literal: true

# name: discourse-geoblocking
# about: Restricts access to content based upon the user's geographical location (IP location).
# version: 0.1
# url: https://github.com/discourse-org/discourse-geoblocking

enabled_site_setting :geoblocking_enabled

require_relative("lib/geoblocking_middleware")

DiscourseEvent.on(:after_initializers) do
  # Must be added after DebugExceptions so that postgres errors trigger failover
  middleware =
    if defined?(Logster::Middleware::DebugExceptions)
      Logster::Middleware::DebugExceptions
    else
      ActionDispatch::DebugExceptions
    end

  Rails.configuration.middleware.insert_after(middleware, GeoblockingMiddleware)
end

module ::DiscourseGeoblocking
  COUNTRY_CODES = [
    # Custom Country Codes
    { name: 'Anonymous Proxy', value: 'A1' },
    { name: 'Satellite Provider', value: 'A2' },
    { name: 'Asia/Pacific Region', value: 'AP' },
    { name: 'Europe', value: 'EU' },
    { name: 'Other Country', value: 'O1' },
    # ISO 3166
    { name: 'Andorra', value: 'AD' },
    { name: 'United Arab Emirates', value: 'AE' },
    { name: 'Afghanistan', value: 'AF' },
    { name: 'Antigua and Barbuda', value: 'AG' },
    { name: 'Anguilla', value: 'AI' },
    { name: 'Albania', value: 'AL' },
    { name: 'Armenia', value: 'AM' },
    { name: 'Angola', value: 'AO' },
    { name: 'Antarctica', value: 'AQ' },
    { name: 'Argentina', value: 'AR' },
    { name: 'American Samoa', value: 'AS' },
    { name: 'Austria', value: 'AT' },
    { name: 'Australia', value: 'AU' },
    { name: 'Aruba', value: 'AW' },
    { name: 'Aland Islands', value: 'AX' },
    { name: 'Azerbaijan', value: 'AZ' },
    { name: 'Bosnia and Herzegovina', value: 'BA' },
    { name: 'Barbados', value: 'BB' },
    { name: 'Bangladesh', value: 'BD' },
    { name: 'Belgium', value: 'BE' },
    { name: 'Burkina Faso', value: 'BF' },
    { name: 'Bulgaria', value: 'BG' },
    { name: 'Bahrain', value: 'BH' },
    { name: 'Burundi', value: 'BI' },
    { name: 'Benin', value: 'BJ' },
    { name: 'Saint Barthelemey', value: 'BL' },
    { name: 'Bermuda', value: 'BM' },
    { name: 'Brunei Darussalam', value: 'BN' },
    { name: 'Bolivia', value: 'BO' },
    { name: 'Bonaire, Saint Eustatius and Saba', value: 'BQ' },
    { name: 'Brazil', value: 'BR' },
    { name: 'Bahamas', value: 'BS' },
    { name: 'Bhutan', value: 'BT' },
    { name: 'Bouvet Island', value: 'BV' },
    { name: 'Botswana', value: 'BW' },
    { name: 'Belarus', value: 'BY' },
    { name: 'Belize', value: 'BZ' },
    { name: 'Canada', value: 'CA' },
    { name: 'Cocos (Keeling) Islands', value: 'CC' },
    { name: 'Congo, The Democratic Republic of the', value: 'CD' },
    { name: 'Central African Republic', value: 'CF' },
    { name: 'Congo', value: 'CG' },
    { name: 'Switzerland', value: 'CH' },
    { name: 'Cote d\'Ivoire', value: 'CI' },
    { name: 'Cook Islands', value: 'CK' },
    { name: 'Chile', value: 'CL' },
    { name: 'Cameroon', value: 'CM' },
    { name: 'China', value: 'CN' },
    { name: 'Colombia', value: 'CO' },
    { name: 'Costa Rica', value: 'CR' },
    { name: 'Serbia and Montenegro', value: 'CS' },
    { name: 'Cuba', value: 'CU' },
    { name: 'Cape Verde', value: 'CV' },
    { name: 'Curacao', value: 'CW' },
    { name: 'Christmas Island', value: 'CX' },
    { name: 'Cyprus', value: 'CY' },
    { name: 'Czech Republic', value: 'CZ' },
    { name: 'Germany', value: 'DE' },
    { name: 'Djibouti', value: 'DJ' },
    { name: 'Denmark', value: 'DK' },
    { name: 'Dominica', value: 'DM' },
    { name: 'Dominican Republic', value: 'DO' },
    { name: 'Algeria', value: 'DZ' },
    { name: 'Ecuador', value: 'EC' },
    { name: 'Estonia', value: 'EE' },
    { name: 'Egypt', value: 'EG' },
    { name: 'Western Sahara', value: 'EH' },
    { name: 'Eritrea', value: 'ER' },
    { name: 'Spain', value: 'ES' },
    { name: 'Ethiopia', value: 'ET' },
    { name: 'Finland', value: 'FI' },
    { name: 'Fiji', value: 'FJ' },
    { name: 'Falkland Islands (Malvinas)', value: 'FK' },
    { name: 'Micronesia, Federated States of', value: 'FM' },
    { name: 'Faroe Islands', value: 'FO' },
    { name: 'France', value: 'FR' },
    { name: 'France, Metropolitan', value: 'FX' },
    { name: 'Gabon', value: 'GA' },
    { name: 'United Kingdom', value: 'GB' },
    { name: 'Grenada', value: 'GD' },
    { name: 'Georgia', value: 'GE' },
    { name: 'French Guiana', value: 'GF' },
    { name: 'Guernsey', value: 'GG' },
    { name: 'Ghana', value: 'GH' },
    { name: 'Gibraltar', value: 'GI' },
    { name: 'Greenland', value: 'GL' },
    { name: 'Gambia', value: 'GM' },
    { name: 'Guinea', value: 'GN' },
    { name: 'Guadeloupe', value: 'GP' },
    { name: 'Equatorial Guinea', value: 'GQ' },
    { name: 'Greece', value: 'GR' },
    { name: 'South Georgia and the South Sandwich Islands', value: 'GS' },
    { name: 'Guatemala', value: 'GT' },
    { name: 'Guam', value: 'GU' },
    { name: 'Guinea-Bissau', value: 'GW' },
    { name: 'Guyana', value: 'GY' },
    { name: 'Hong Kong', value: 'HK' },
    { name: 'Heard Island and McDonald Islands', value: 'HM' },
    { name: 'Honduras', value: 'HN' },
    { name: 'Croatia', value: 'HR' },
    { name: 'Haiti', value: 'HT' },
    { name: 'Hungary', value: 'HU' },
    { name: 'Indonesia', value: 'ID' },
    { name: 'Ireland', value: 'IE' },
    { name: 'Israel', value: 'IL' },
    { name: 'Isle of Man', value: 'IM' },
    { name: 'India', value: 'IN' },
    { name: 'British Indian Ocean Territory', value: 'IO' },
    { name: 'Iraq', value: 'IQ' },
    { name: 'Iran, Islamic Republic of', value: 'IR' },
    { name: 'Iceland', value: 'IS' },
    { name: 'Italy', value: 'IT' },
    { name: 'Jersey', value: 'JE' },
    { name: 'Jamaica', value: 'JM' },
    { name: 'Jordan', value: 'JO' },
    { name: 'Japan', value: 'JP' },
    { name: 'Kenya', value: 'KE' },
    { name: 'Kyrgyzstan', value: 'KG' },
    { name: 'Cambodia', value: 'KH' },
    { name: 'Kiribati', value: 'KI' },
    { name: 'Comoros', value: 'KM' },
    { name: 'Saint Kitts and Nevis', value: 'KN' },
    { name: 'Korea, Democratic People\'s Republic of', value: 'KP' },
    { name: 'Korea, Republic of', value: 'KR' },
    { name: 'Kuwait', value: 'KW' },
    { name: 'Cayman Islands', value: 'KY' },
    { name: 'Kazakhstan', value: 'KZ' },
    { name: 'Lao People\'s Democratic Republic', value: 'LA' },
    { name: 'Lebanon', value: 'LB' },
    { name: 'Saint Lucia', value: 'LC' },
    { name: 'Liechtenstein', value: 'LI' },
    { name: 'Sri Lanka', value: 'LK' },
    { name: 'Liberia', value: 'LR' },
    { name: 'Lesotho', value: 'LS' },
    { name: 'Lithuania', value: 'LT' },
    { name: 'Luxembourg', value: 'LU' },
    { name: 'Latvia', value: 'LV' },
    { name: 'Libyan Arab Jamahiriya', value: 'LY' },
    { name: 'Morocco', value: 'MA' },
    { name: 'Monaco', value: 'MC' },
    { name: 'Moldova, Republic of', value: 'MD' },
    { name: 'Montenegro', value: 'ME' },
    { name: 'Saint Martin', value: 'MF' },
    { name: 'Madagascar', value: 'MG' },
    { name: 'Marshall Islands', value: 'MH' },
    { name: 'Macedonia', value: 'MK' },
    { name: 'Mali', value: 'ML' },
    { name: 'Myanmar', value: 'MM' },
    { name: 'Mongolia', value: 'MN' },
    { name: 'Macao', value: 'MO' },
    { name: 'Macau', value: 'MO' },
    { name: 'Northern Mariana Islands', value: 'MP' },
    { name: 'Martinique', value: 'MQ' },
    { name: 'Mauritania', value: 'MR' },
    { name: 'Montserrat', value: 'MS' },
    { name: 'Malta', value: 'MT' },
    { name: 'Mauritius', value: 'MU' },
    { name: 'Maldives', value: 'MV' },
    { name: 'Malawi', value: 'MW' },
    { name: 'Mexico', value: 'MX' },
    { name: 'Malaysia', value: 'MY' },
    { name: 'Mozambique', value: 'MZ' },
    { name: 'Namibia', value: 'NA' },
    { name: 'New Caledonia', value: 'NC' },
    { name: 'Niger', value: 'NE' },
    { name: 'Norfolk Island', value: 'NF' },
    { name: 'Nigeria', value: 'NG' },
    { name: 'Nicaragua', value: 'NI' },
    { name: 'Netherlands', value: 'NL' },
    { name: 'Norway', value: 'NO' },
    { name: 'Nepal', value: 'NP' },
    { name: 'Nauru', value: 'NR' },
    { name: 'Niue', value: 'NU' },
    { name: 'New Zealand', value: 'NZ' },
    { name: 'Oman', value: 'OM' },
    { name: 'Panama', value: 'PA' },
    { name: 'Peru', value: 'PE' },
    { name: 'French Polynesia', value: 'PF' },
    { name: 'Papua New Guinea', value: 'PG' },
    { name: 'Philippines', value: 'PH' },
    { name: 'Pakistan', value: 'PK' },
    { name: 'Poland', value: 'PL' },
    { name: 'Saint Pierre and Miquelon', value: 'PM' },
    { name: 'Pitcairn', value: 'PN' },
    { name: 'Puerto Rico', value: 'PR' },
    { name: 'Palestinian Territory', value: 'PS' },
    { name: 'Portugal', value: 'PT' },
    { name: 'Palau', value: 'PW' },
    { name: 'Paraguay', value: 'PY' },
    { name: 'Qatar', value: 'QA' },
    { name: 'Reunion', value: 'RE' },
    { name: 'Romania', value: 'RO' },
    { name: 'Serbia', value: 'RS' },
    { name: 'Russian Federation', value: 'RU' },
    { name: 'Rwanda', value: 'RW' },
    { name: 'Saudi Arabia', value: 'SA' },
    { name: 'Solomon Islands', value: 'SB' },
    { name: 'Seychelles', value: 'SC' },
    { name: 'Sudan', value: 'SD' },
    { name: 'Sweden', value: 'SE' },
    { name: 'Singapore', value: 'SG' },
    { name: 'Saint Helena', value: 'SH' },
    { name: 'Slovenia', value: 'SI' },
    { name: 'Svalbard and Jan Mayen', value: 'SJ' },
    { name: 'Slovakia', value: 'SK' },
    { name: 'Sierra Leone', value: 'SL' },
    { name: 'San Marino', value: 'SM' },
    { name: 'Senegal', value: 'SN' },
    { name: 'Somalia', value: 'SO' },
    { name: 'Suriname', value: 'SR' },
    { name: 'South Sudan', value: 'SS' },
    { name: 'Sao Tome and Principe', value: 'ST' },
    { name: 'El Salvador', value: 'SV' },
    { name: 'Sint Maarten', value: 'SX' },
    { name: 'Syrian Arab Republic', value: 'SY' },
    { name: 'Swaziland', value: 'SZ' },
    { name: 'Turks and Caicos Islands', value: 'TC' },
    { name: 'Chad', value: 'TD' },
    { name: 'French Southern Territories', value: 'TF' },
    { name: 'Togo', value: 'TG' },
    { name: 'Thailand', value: 'TH' },
    { name: 'Tajikistan', value: 'TJ' },
    { name: 'Tokelau', value: 'TK' },
    { name: 'Timor-Leste', value: 'TL' },
    { name: 'Turkmenistan', value: 'TM' },
    { name: 'Tunisia', value: 'TN' },
    { name: 'Tonga', value: 'TO' },
    { name: 'Turkey', value: 'TR' },
    { name: 'Trinidad and Tobago', value: 'TT' },
    { name: 'Tuvalu', value: 'TV' },
    { name: 'Taiwan', value: 'TW' },
    { name: 'Tanzania, United Republic of', value: 'TZ' },
    { name: 'Ukraine', value: 'UA' },
    { name: 'Uganda', value: 'UG' },
    { name: 'United States Minor Outlying Islands', value: 'UM' },
    { name: 'United States', value: 'US' },
    { name: 'Uruguay', value: 'UY' },
    { name: 'Uzbekistan', value: 'UZ' },
    { name: 'Holy See (Vatican City State)', value: 'VA' },
    { name: 'Saint Vincent and the Grenadines', value: 'VC' },
    { name: 'Venezuela', value: 'VE' },
    { name: 'Virgin Islands, British', value: 'VG' },
    { name: 'Virgin Islands, U.S.', value: 'VI' },
    { name: 'Vietnam', value: 'VN' },
    { name: 'Vanuatu', value: 'VU' },
    { name: 'Wallis and Futuna', value: 'WF' },
    { name: 'Samoa', value: 'WS' },
    { name: 'Yemen', value: 'YE' },
    { name: 'Mayotte', value: 'YT' },
    { name: 'South Africa', value: 'ZA' },
    { name: 'Zambia', value: 'ZM' },
    { name: 'Zimbabwe', value: 'ZW' },
  ]
end

after_initialize do
  require_relative("app/controllers/geoblocking_controller")

  module ::DiscourseGeoblocking
    PLUGIN_NAME = 'discourse-geoblocking'

    def self.cache
      @cache ||= DistributedCache.new(PLUGIN_NAME)
    end

    def self.reset_cache!
      cache.clear
    end

    def self.allowed_countries
      cache['geoblocking_allowed_countries'] ||= SiteSetting.geoblocking_allowed_countries.upcase.split("|").to_set
    end

    def self.allowed_geoname_ids
      cache['geoblocking_allowed_geoname_ids'] ||= SiteSetting.geoblocking_allowed_geoname_ids.split("|").map(&:to_i).to_set
    end

    def self.blocked_countries
      cache['geoblocking_blocked_countries'] ||= SiteSetting.geoblocking_blocked_countries.upcase.split("|").to_set
    end

    def self.blocked_geoname_ids
      cache['geoblocking_blocked_geoname_ids'] ||= SiteSetting.geoblocking_blocked_geoname_ids.split("|").map(&:to_i).to_set
    end
  end

  on(:site_setting_changed) do |name, old_value, new_value|
    if [:geoblocking_allowed_countries,
        :geoblocking_allowed_geoname_ids,
        :geoblocking_blocked_countries,
        :geoblocking_blocked_geoname_ids].include?(name)
      DiscourseGeoblocking.reset_cache!
    end
  end
end
