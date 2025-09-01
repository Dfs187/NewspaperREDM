-- config.lua - Lets Pray this works 
Config = {}

-- Price Configuration
Config.ITEM_PRICES = {
    ['crime_report']        = 0,
    ['latest_news']         = 3,
    ['business_bulletin']   = 20,
    ['private_sales']       = 10,
    ['ad_placement']        = 50,
    ['community_activities']= 5,
    ['opinion']             = 2,
    ['misc']                = 2
}

Config.NEWSPAPER_PRICE = 3

-- Constants (replacing magic numbers)
Config.CONSTANTS = {
    INTERACTION_DISTANCE = 2.0,
    THREAD_WAIT_TIME = 1000,
    FRAMEWORK_LOAD_ATTEMPTS = 10,
    FRAMEWORK_WAIT_TIME = 500,
    MAX_TITLE_LENGTH = 100,
    MAX_CONTENT_LENGTH = 2000,
    MAX_CRAFT_QUANTITY = 100,
    MIN_CRAFT_QUANTITY = 1
}

-- Security Settings
Config.SECURITY = {
    RATE_LIMIT_WINDOW = 60000, -- 1 minute in milliseconds
    MAX_SUBMISSIONS_PER_WINDOW = 3,
    ALLOWED_IMAGE_DOMAINS = {
        'i.imgur.com',
        'cdn.discordapp.com',
        'i.pinimg.com',
        'media.istockphoto.com',
        'i.ibb.co' -- Added for the new stable links
    },
    BLOCKED_WORDS = {
        -- Add any words you want to filter from submissions
        'script', 'javascript', 'onclick', 'onerror', 'onload'
    }
}

-- Valid submission types (Must match the keys in ITEM_PRICES)
Config.VALID_SUBMISSION_TYPES = {
    'crime_report',
    'latest_news',
    'business_bulletin', 
    'private_sales',
    'ad_placement',
    'community_activities',
    'opinion',
    'misc'
}

-- Valid location types for admin commands
Config.VALID_LOCATION_TYPES = {
    'duty',
    'store', 
    'typewriter',
    'payout'
}