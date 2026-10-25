function escapeHtml(value) { return String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
const Formats = {
    category_option: `
        <div class="category-option">
            <div>
                <img onerror="this.style.opacity=0" src="assets/images/$[IMAGE]">
            </div>
            <div>
                <div>
                    <div>$[LABEL]</div>
                </div>
                <div>
                    <div>$[DESCRIPTION]</div>
                </div>
            </div>
            <div>
                <span class="mdi mdi-chevron-down dropdown"></span>
            </div>
        </div>
    `,
    item_option: `
        <div id="item-$[INDEX]" class="item-option $[CLASS]">
            <div>
                <img onerror="this.style.opacity=0" src="$[IMAGE]">
            </div>
            <div>
                <div>
                    <div>$[LABEL]</div>
                </div>
                <div>
                    <div>$[DESCRIPTION]</div>
                </div>
            </div>
        </div>
    `,
    part_option: `
        <div class="part-item $[CLASS]">
            <div>
                <img onerror="this.style.opacity=0" src="$[IMAGE]">
            </div>
            <div>
                <div>
                    <span class="secondary small">x$[AMOUNT]</span><div class="primary small">$[LABEL]</div>
                </div>
            </div>
        </div>
    `,
    blueprint: `
        <div class="part-item $[CLASS]">
            <div>
                <img onerror="this.style.opacity=0" src="$[IMAGE]">
            </div>
            <div>
                <div>
                    <div class="primary small">$[LABEL]</div>
                </div>
            </div>
        </div>
    `,
    xp: `
        <div class="part-item $[CLASS]">
            <div>
                <img onerror="this.style.opacity=0" src="$[IMAGE]">
            </div>
            <div>
                <div>
                    <span class="secondary small">Level $[LEVEL]</span><div class="primary small">$[LABEL]</div>
                </div>
            </div>
        </div>
    `,
    reward: `
        <div class="part-item">
            <div>
                <img onerror="this.style.opacity=0" src="$[IMAGE]">
            </div>
            <div>
                <div>
                    <span class="secondary small">$[AMOUNT]</span><div class="primary small">$[LABEL]</div>
                </div>
            </div>
        </div>
    `,
    craft_display: `
        <div class="primary">Description</div>
        <div class="secondary">$[DESCRIPTION]</div>
        <div class="primary">Time</div>
        <div class="secondary">$[TIME] Seconds</div>
        <div class="primary">Parts</div>
        $[PARTS]
        <div class="primary">Blueprint</div>
        $[BLUEPRINT]
        <div class="primary">Experience</div>
        $[XP]
        <div class="primary">Rewards</div>
        $[REWARDS]
    `,
    queue_item: `
        <div id="queue-$[INDEX]" class="queue-item">
            <div>
                <img onerror="this.style.opacity=0" src="$[IMAGE]">
            </div>
            <div>
                <div>
                    <div>$[LABEL]</div>
                    <div id="queue-quantity-$[INDEX]">$[QUANTITY]</div>
                    <span class="queue-cancel mdi mdi-close"></span>
                </div>
                <div>
                    <div id="queue-timer-$[INDEX]">$[TIMER]</div>
                </div>
            </div>
        </div>
    `,
    queue_collect: `
        <div class="queue-collect">COLLECT</div>
    `
}

let Config = {}

let Queue = {}
let CurrentTable;
let CurrentItem;
let CurrentQuantity = 1;

let inventory;
let categories;
let items;
let xpData;

function post(type, data) {
    fetch(`https://pickle_crafting/${type}`, {
        method: 'post',
        headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data || {})
    })
    .then(response => {  })
    .catch(error => {  });
}

function GetItemCount(name) {
    for (let i=0; i<inventory.length; i++) {
        let item = inventory[i];
        if (item.name == name) {
            return item.count;
        }
    }
    return 0;
}

function DisplayCraft(index, quantity) {
    if (index == undefined) return;
    CurrentItem = index;
    let multiplier = quantity || 1;
    let middleHtml = Formats.craft_display;
    let item = items[index];
    middleHtml = middleHtml.replaceAll("$[DESCRIPTION]", escapeHtml(item.description || "No description."));
    middleHtml = middleHtml.replaceAll("$[TIME]", item.time * multiplier)
    if (typeof xpData !== 'undefined' && item.xp && Config.XPCategories[item.xp.name]) {
        let xp = Config.XPCategories[item.xp.name];
        let xpHtml = Formats.xp;
        xpHtml = xpHtml.replaceAll("$[IMAGE]", "assets/images/" + xp.image);
        xpHtml = xpHtml.replaceAll("$[LABEL]", escapeHtml(xp.label));
        xpHtml = xpHtml.replaceAll("$[LEVEL]", item.xp.level);
        if (!xpData[item.xp.name] || xpData[item.xp.name].level < item.xp.level) {
            xpHtml = xpHtml.replaceAll("$[CLASS]", "part-disabled");
        }
        else {
            xpHtml = xpHtml.replaceAll("$[CLASS]", "part-enabled");
        }
        middleHtml = middleHtml.replaceAll("$[XP]", xpHtml);
    }
    else {
        middleHtml = middleHtml.replaceAll("$[XP]", `<div class="secondary">No XP needed.</div>`);
    }
    if (item.parts && item.parts.length > 0) {
        let partsHtml = "<div>";
        let parts = item.parts;
        for (let i=0; i<parts.length; i++) {
            let partHtml = Formats.part_option;
            let part = parts[i];
            if (inventory) {
                partHtml = partHtml.replaceAll("$[CLASS]", GetItemCount(part.name) - (part.amount * multiplier) >= 0 ? "part-enabled" : "part-disabled");
            }
            else {
                partHtml = partHtml.replaceAll("$[CLASS]", "part-enabled");
            }
            partHtml = partHtml.replaceAll("$[IMAGE]", Config.ItemImageFolder + "/" + part.name + ".png");
            partHtml = partHtml.replaceAll("$[AMOUNT]", part.amount * multiplier);
            partHtml = partHtml.replaceAll("$[LABEL]", escapeHtml(part.label || (Config.Items[part.name]?.label || part.name)));
            partsHtml += partHtml;
        }
        partsHtml += "</div>";
        middleHtml = middleHtml.replaceAll("$[PARTS]", partsHtml);
    }
    else {
        middleHtml = middleHtml.replaceAll("$[PARTS]", `<div class="secondary">No parts needed.</div>`);
    }
    if (item.blueprint && Config.Blueprints[item.blueprint]) {
        let blueprintHtml = "<div>" + Formats.blueprint;
        let blueprint = Config.Blueprints[item.blueprint];
        blueprintHtml = blueprintHtml.replaceAll("$[CLASS]", blueprint.enabled ? "blueprint-enabled" : "blueprint-disabled");
        blueprintHtml = blueprintHtml.replaceAll("$[IMAGE]", "assets/images/" + blueprint.image);
        blueprintHtml = blueprintHtml.replaceAll("$[LABEL]", escapeHtml(blueprint.label));
        blueprintHtml += "</div>";
        middleHtml = middleHtml.replaceAll("$[BLUEPRINT]", blueprintHtml);
    }
    else {
        middleHtml = middleHtml.replaceAll("$[BLUEPRINT]", `<div class="secondary">No blueprint needed.</div>`);
    }
    let rewardsHtml = "<div>";

    let rewardHtml = Formats.reward;
    rewardHtml = rewardHtml.replaceAll("$[IMAGE]", Config.ItemImageFolder + "/" + item.name + ".png");
    rewardHtml = rewardHtml.replaceAll("$[AMOUNT]", "x" + (item.amount * multiplier));
    rewardHtml = rewardHtml.replaceAll("$[LABEL]", escapeHtml(item.label || (Config.Items[item.name]?.label || item.name)));
    rewardsHtml += rewardHtml;

    if (item.rewards && item.rewards.length > 0) {
        let rewards = item.rewards;
        for (let i=0; i<rewards.length; i++) {
            let rewardHtml = Formats.reward;
            let reward = rewards[i];
            let amount = reward.amount * multiplier;
            let image = reward.image;
            let label = reward.label;
            let exist = true;
            if (reward.type == "xp") {
                if (Config.XPCategories[reward.name]) {
                    amount = "+" + amount;
                    image = "assets/images/" + Config.XPCategories[reward.name].image;
                    label = Config.XPCategories[reward.name].label + " XP";
                }
                else {
                    exist = false;
                }
            }
            else {
                if (Config.Items[reward.name]) {
                    amount = "x" + amount;
                    image = reward.image || Config.ItemImageFolder + "/" + reward.name + ".png";
                    label = reward.label || (Config.Items[reward.name]?.label || reward.name);
                }
                else {
                    exist = false;
                }
            }
            if (exist) {
                rewardHtml = rewardHtml.replaceAll("$[IMAGE]", image);
                rewardHtml = rewardHtml.replaceAll("$[AMOUNT]", amount);
                rewardHtml = rewardHtml.replaceAll("$[LABEL]", escapeHtml(label));
                rewardsHtml += rewardHtml;
            }
        }
    }
    rewardsHtml += "</div>";
    middleHtml = middleHtml.replaceAll("$[REWARDS]", rewardsHtml);
    CurrentQuantity = multiplier;
    $("#lc-title").html(item.label || (Config.Items[item.name]?.label || item.name));
    $("#lc-image").html();//`<img onerror="this.style.opacity=0" src="${Config.ItemImageFolder + "/" + item.name + ".png"}">`);
    $("#lc-middle").html(middleHtml);
    $(".quantity-amount").html("x" + CurrentQuantity);
    
    $(".item-option").removeClass("selected");
    $("#item-"+index).addClass("selected");
    if (!$("#left-container").is(":visible")) {
        $("#left-container").css("display", "flex").hide().fadeIn();
    }
    post("itemSelect", {index: CurrentItem + 1})
}

function DisplayInt(float) {
    var floor = Math.floor(float)
    if (floor < 10) {
        floor = "0" + floor;
    }
    return floor;
}

function FormatTimer(timer) {
    var minutes = Math.floor(timer / 60);
    var seconds = timer - minutes * 60;
    if (minutes < 0) {
        return `00:00`;
    }
    return (DisplayInt(minutes) + ":" + DisplayInt(seconds))
}

function GetQueueHtml(index, quantity, time) {
    let item = items[index];
    let queueHtml = Formats.queue_item;
    queueHtml = queueHtml.replaceAll("$[INDEX]", index);
    queueHtml = queueHtml.replaceAll("$[LABEL]", escapeHtml(item.label || (Config.Items[item.name]?.label || item.name)));
    queueHtml = queueHtml.replaceAll("$[IMAGE]", Config.ItemImageFolder + "/" + item.name + ".png");
    queueHtml = queueHtml.replaceAll("$[QUANTITY]", "x" + quantity);
    queueHtml = queueHtml.replaceAll("$[TIMER]", FormatTimer(time || (item.time * quantity)));
    return queueHtml;
}

function ActiveQueue(index, quantity) {
    let item = items[index];
    let interval = setInterval(() => {
        let queue = Queue[index];
        if (!queue) { 
            clearInterval(interval);
            return;
        }
        queue.timer -= 1;
        
        if ($("#queue-"+index).length < 1) {
            $("#queue-container").append(GetQueueHtml(index, quantity, queue.timer));
            setTimeout(() => {
            }, 100);
        }
        else if (!$("#queue-"+index).hasClass("active")) {
            $("#queue-"+index).addClass("active");
        }
        if (queue.timer <= 0) {
            clearInterval(interval);
            $("#queue-timer-"+index).html(Formats.queue_collect);
            return;
        }
        $("#queue-quantity-"+index).html("x"+quantity);
        $("#queue-timer-"+index).html(FormatTimer(queue.timer));
    }, 1000);
    Queue[index].interval = interval;
}

function DisplayQueue(index, quantity, time) {
    if (Queue[index]) {
        Queue[index].timer = time;
        if (!Queue[index].interval) {
            ActiveQueue(index, quantity)
        }
        return;
    }
    let item = items[index];
    Queue[index] = {
        timer: item.time * quantity,
        timeFactor: item.time
    };
    $("#queue-container").prepend(GetQueueHtml(index, quantity, time));
    setTimeout(() => {
        $("#queue-"+index).addClass("active");
        if (Queue[index].timer <= 0) {
            $("#queue-timer-"+index).html(Formats.queue_collect);
        }
    }, 100);
    if (time) {
        Queue[index].timer = time;
        ActiveQueue(index, quantity)
    }
}

function RemoveQueue(index) {
    const old = Queue[index];
    if (old?.interval) clearInterval(old.interval);
    delete Queue[index];
    let item = items[index];
    if ($("#queue-"+index).length) {
        $("#queue-"+index).removeClass("active");
        const oldElement = $("#queue-"+index);
        setTimeout(()=>{
            if (!Queue[index]) oldElement.remove()
        }, 1000)
    }
}

function RefreshInventory(data) {
    inventory = data;
    if (!inventory) return;
    for (let i=0; i<items.length; i++) {
        let item = items[i];
        let element = $("#item-" + i);
        if (item.parts && item.parts.length > 0) {
            let parts = item.parts;
            let enabled = true;
            for (let j=0; j<parts.length; j++) {
                let part = parts[j];
                if (GetItemCount(part.name) - part.amount < 0) {
                    enabled = false;
                }
            }
            element.removeClass(enabled ? "item-disabled" : "item-enabled");
            element.addClass(enabled ? "item-enabled" : "item-disabled");
        }
    }
    if (CurrentItem != undefined) {
        UpdateQuantity()
    }
}

function RefreshXP(data) {
    xpData = data;
    if (typeof xpData === 'undefined') return;
    for (let i=0; i<items.length; i++) {
        let item = items[i];
        let element = $("#item-" + i);
        if (item.xp) {
            element.removeClass((item.xp.level <= xpData[item.xp.name].level) ? "item-disabled" : "item-enabled");
            element.addClass((item.xp.level <= xpData[item.xp.name].level) ? "item-enabled" : "item-disabled");
        }
    }
    if (CurrentItem != undefined) {
        UpdateQuantity()
    }
}

function UpdateQuantity() {
    $(".quantity-amount").html("x" + CurrentQuantity)
    DisplayCraft(CurrentItem, CurrentQuantity)
}

function InitializeCrafting(craftingData, hide) {
    var index;
    var data;
    if (craftingData.xpData) {
        xpData = craftingData.xpData;
    }
    if (craftingData.inventory) {
        index = craftingData.table.index;
        data = craftingData.table.data;
        inventory = craftingData.inventory;
    }
    else {
        index = craftingData.index;
        data = craftingData.data;
        delete inventory;
    }

    let middleHtml = "";

    CurrentTable = index;
    categories = data.categories;
    items = data.items;
    
    for (let i=0; i<categories.length; i++) {
        let category = categories[i];
        let template = Formats.category_option;
        let itemsHtml = "";
        let found = false;

        template = template.replaceAll("$[IMAGE]", category.image);
        template = template.replaceAll("$[LABEL]", escapeHtml(category.label));
        template = template.replaceAll("$[DESCRIPTION]", escapeHtml(category.description || "No description."));
        middleHtml += template
        
        for (let j=0; j<items.length; j++) {
            let item = items[j];
            let itemTemplate = Formats.item_option;
            if (item.category == category.name) {
                found = true;
                let enabled = true;
                if (inventory && item.parts && item.parts.length > 0) {
                    let parts = item.parts;
                    for (let i=0; i<parts.length; i++) {
                        let partHtml = Formats.part_option;
                        let part = parts[i];
                        if (GetItemCount(part.name) - part.amount < 0) {
                            enabled = false;
                        }
                    }
                }
                if (item.xp && !(xpData && xpData[item.xp.name] && Config.XPCategories[item.xp.name] && item.xp.level <= xpData[item.xp.name].level)) {
                    enabled = false;
                }
                if (Config.Items[item.name]) {
                    itemTemplate = itemTemplate.replaceAll("$[CLASS]", enabled ? "item-enabled" : "item-disabled");
                    itemTemplate = itemTemplate.replaceAll("$[INDEX]", j);
                    itemTemplate = itemTemplate.replaceAll("$[IMAGE]", Config.ItemImageFolder + "/" + item.name + ".png");
                    itemTemplate = itemTemplate.replaceAll("$[LABEL]", escapeHtml(item.label || (Config.Items[item.name]?.label || item.name)));
                    itemTemplate = itemTemplate.replaceAll("$[DESCRIPTION]", escapeHtml(item.description || "No description."));
                    itemsHtml += itemTemplate;
                }
            }
        }
        if (!found) {
            middleHtml += `<div class="category-list centered">No items are craftable in this category.</div>`
        }
        else {
            middleHtml += `<div class="category-list">${itemsHtml}</div>`
        }
    }
    $("#rc-middle").html(middleHtml);
    $("#left-container").hide();
    if (!hide) {
        $("#right-container").css("display", "flex").hide().fadeIn();
        $("#queue-container").addClass("screen-active");
    }
}

function HideCrafting() {
    delete CurrentItem;
    $("#left-container").fadeOut();
    $("#right-container").fadeOut();
    $("#queue-container").removeClass("screen-active");
    post("hide")
}

$(document).ready(function () {
    // 

    // AddQueue(1, 3)
    
    $(document).on("click", ".category-option", function(event) {
        var dropdown = $(this).find(".dropdown")
        var element = $(this).next(".category-list")
        if (element.is(":visible")) {
            element.slideUp()
            dropdown.removeClass("active")
        }
        else {
            element.slideDown({
                start: function () {
                  $(this).css({
                    display: "flex"
                  })
                }
            });
            dropdown.addClass("active")
        }
    })
    $(document).on("click", ".item-option", function(event) {
        let index = Number($(this).attr("id").replaceAll("item-", ""));
        DisplayCraft(index)
    })
    $(document).on("click", ".queue-cancel", function(event) {
        let index = Number($(this).parent().parent().parent().attr("id").replaceAll("queue-", ""))
        post("cancelQueue", {index: index + 1});
    })
    $(document).on("click", ".queue-collect", function(event) {
        let index = Number($(this).parent().parent().parent().parent().attr("id").replaceAll("queue-", ""))
        post("collectQueue", {index: index + 1});
    })
    $(document).on("click", ".quantity-plus", function(event) {
        CurrentQuantity += 1;
        UpdateQuantity();
    })
    $(document).on("click", ".quantity-minus", function(event) {
        if (CurrentQuantity > 1) {
            CurrentQuantity -= 1;
            UpdateQuantity();
        }
    })
    $(document).on("click", ".exit", function(event) {
        HideCrafting()
    })
    $(document).on("click", ".submit", function(event) {
        post("startCrafting", {
            index: CurrentItem + 1,
            quantity: CurrentQuantity
        })
    })
})

window.addEventListener("message", function(ev) {
    var event = ev.data
    if (event.type == "updateConfig") {
        Config = event.data;
    }
    else if (event.type == "show") {
        InitializeCrafting(event.data)
    }
    else if (event.type == "hide") {
        HideCrafting()
    }
    else if (event.type == "displayQueue") {
        if (event.data.tableIndex != CurrentTable) return;
        DisplayQueue(event.data.index - 1, event.data.quantity, event.data.time)
    }
    else if (event.type == "removeQueue") {
        if (event.data.tableIndex != CurrentTable) return;
        RemoveQueue(event.data.index - 1)
    }
    else if (event.type == "hideQueue") {
        for (const [key, value] of Object.entries(Queue)) {
            RemoveQueue(key);
        }          
    }
    else if (event.type == "refreshInventory") {
        RefreshInventory(event.data)
    }
    else if (event.type == "refreshXP") {
        RefreshXP(event.data)
    }
    else if (event.type == "initTable") {
        InitializeCrafting(event.data, true)
    }
})
