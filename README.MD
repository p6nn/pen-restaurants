# UI Preview

https://streamable.com/j59ymu

# TO - DO

fix revenue and online staff count
fix issue where duty status doesn’t reset correctly, especially when a player is clocking off for the first time or when changing duty status after the resource starts.

# FiveM Restaurant System (WIP)

A fully customisable, **roleplay-focused restaurant system** for FiveM, built for **Qbox** with **ox_lib**, **ox_inventory**, and a modern **Mantine React UI**.  
It provides an immersive workflow from taking orders to preparing, serving, and managing a restaurant business — both in-game and via a sleek management interface.

---

## ✨ Features

- **Modern Mantine UI**  
  Clean, responsive interface for both cooking and business management.  
  Includes dedicated panels for inventory, recipes, menu, staff, and sales statistics.

- **Cooking System**  
  Create dishes using configured recipes and ingredients from `ox_inventory`.  
  Supports custom recipe creation directly in-game.

- **Drive-Thru System**  
  Connects a drive-thru worker and a customer in real-time for seamless voice and order roleplay.

- **Ingredient & Stock Management**  
  Integrated shop system for purchasing ingredients. Prices and items are fully configurable.

- **Trays & Stash System**  
  Place trays in the world that dynamically display items added to them.  
  Restaurant-specific stashes for ingredients and prepared meals.

- **Registers & Payments**  
  Functional registers allow charging customers directly, with payments going to the business account.

- **Clock-In & Shift Tracking**  
  Configurable clock-in points for restaurant roles.  
  Management UI shows online staff and full clock-in/clock-out history.

- **Business Management Panel**  
  View revenue, transactions, and tips.  
  Manage recipes, staff, stock, and menu from one interface.

- **Highly Configurable**  
  All job roles, grades, UI texts, and locations can be set in the config file.

---

## 🛠 Planned Features

- **Enhanced Table Service**  
  Place trays directly on tables with live item updates.

- **Customer Menu Preview**  
  Show customers a visual menu when they sit down, complete with dish images.

- **Expanded Register Features**  
  Add discounts, split payments, and custom notes per order.

- **Company Financial Overview**  
  More detailed transaction and revenue breakdown in the management UI.

---

## 📦 Installation

1. **Download & extract** this resource into your server’s `resources` folder.  
2. Ensure the dependencies are installed:
   - [ox_lib](https://github.com/overextended/ox_lib)
   - [ox_inventory](https://github.com/overextended/ox_inventory)
   - Qbox Framework
3. Add the resource to your `server.cfg`:
   ```cfg
   ensure pen-restaurant
