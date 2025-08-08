Config = {
    debug = true,
    
    shopPrices = {
        noodles = {price = 5, item = "noodles"},
        sauce = {price = 3, item = "tomato_sauce"},
        cheese = {price = 4, item = "cheese_block"},
        meat = {price = 8, item = "raw_beef"},
        chicken = {price = 7, item = "raw_chicken"},
        fish = {price = 9, item = "raw_fish"},
        spices = {price = 2, item = "mixed_spices"},
        vegetables = {price = 3, item = "fresh_vegetables"},
        broth = {price = 4, item = "chicken_broth"},
        herbs = {price = 3, item = "fresh_herbs"},
        truffle = {price = 25, item = "black_truffle"},
        caviar = {price = 50, item = "beluga_caviar"},
        wagyu = {price = 35, item = "wagyu_beef"},
        lobster = {price = 30, item = "live_lobster"},
        flour = {price = 2, item = "wheat_flour"},
        eggs = {price = 4, item = "fresh_eggs"},
        milk = {price = 3, item = "whole_milk"},
        butter = {price = 5, item = "unsalted_butter"},
        oil = {price = 3, item = "olive_oil"},
        salt = {price = 1, item = "sea_salt"},
        pepper = {price = 2, item = "black_pepper"},
        garlic = {price = 2, item = "fresh_garlic"},
        onion = {price = 2, item = "yellow_onion"},
        tomato = {price = 3, item = "ripe_tomato"},
        potato = {price = 2, item = "russet_potato"},
        carrot = {price = 2, item = "fresh_carrot"},
        lettuce = {price = 3, item = "iceberg_lettuce"},
        bread = {price = 4, item = "french_bread"},
        coffee_beans = {price = 6, item = "arabica_beans"},
        tea_leaves = {price = 4, item = "earl_grey_tea"},
        sugar = {price = 2, item = "white_sugar"},
        lemon = {price = 3, item = "fresh_lemon"},
        ice = {price = 1, item = "ice_cubes"}
    },
    
    restaurant = {
        ["The Gourmet Kitchen"] = {
            label = "The Gourmet Kitchen",
            coords = vector3(-1200.0, -900.0, 13.0),
            blip = {
                sprite = 267,
                color = 2,
                scale = 0.8,
                name = "The Gourmet Kitchen",
            },
            requiredJob = "thegourmetkitchen",
            managementAccess = {
                minimumGrade = 2, -- Minimum job grade to access management UI
                allowedGrades = {2, 3, 4}, -- Specific grades that can access (optional, overrides minimumGrade)
                tabAccess = {
                    shop = 0, -- Any grade can buy ingredients
                    menu = 0, -- Any grade can view menu
                    staff = 3 -- Grade 3+ for staff management
                }
            },
            clockInCoords = vector3(-1175.6290, -893.8602, 13.9352),
            driveThruEnabled = true,
            driveThruWorkerCoords = vector3(-1172.4030, -888.0455, 13.9575),
            driveThruCoords = vector3(-1166.5872, -894.6106, 14.0036),
            managementCoords = vector3(-1174.8796, -883.1682, 13.9701),
            stashName = "restaurant_thegourmetkitchen",
            stashCoords = vector3(-1177.2765, -876.1825, 14.0165),
            
            cookingStations = {
                drinks = {
                    vector3(-1170.5, -885.2, 13.97),
                    vector3(-1171.8, -884.9, 13.97)
                },
                food = {
                    vector3(-1174.8796, -883.1682, 13.9701),
                    vector3(-1176.2, -882.8, 13.97),
                    vector3(-1177.5, -882.5, 13.97)
                }
            },
            
            registers = {
                {
                    coords = vector3(-1170.2341, -892.1234, 13.9352),
                    label = "Main Register",
                    requiredGrade = 0
                },
                {
                    coords = vector3(-1168.5674, -890.4567, 13.9352),
                    label = "Counter Register",
                    requiredGrade = 0
                }
            },
            
            trays = {
                ["table_1"] = {
                    coords = vector3(-1165.4523, -885.7891, 13.9352),
                    label = "Table 1 Tray"
                },
                ["table_2"] = {
                    coords = vector3(-1163.2341, -888.1234, 13.9352),
                    label = "Table 2 Tray"
                },
                ["table_3"] = {
                    coords = vector3(-1161.5674, -890.4567, 13.9352),
                    label = "Table 3 Tray"
                },
                ["counter"] = {
                    coords = vector3(-1169.8901, -889.2345, 13.9352),
                    label = "Counter Pickup"
                }
            },
            
            companyAccount = "restaurant_thegourmetkitchen",
            taxRate = 0.1,
            employeePayPercentage = 0.15
        }
    }
}