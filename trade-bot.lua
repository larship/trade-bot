require("helper")
require("config")
require("trends")

PositionData = {
    awg_price = 0,
    count = 0
}

PauseTrading = false

OrderTypeBuy = "B"
OrderTypeSell = "S"

function main()
    log("Запускаем скрипт, " .. _VERSION)

    -- 04-08-2021 11:24:10.358: Money: {
    --  money_open_balance = 296936.38,
    --  money_open_limit = 0.0,
    --  money_limit_available = 296936.38,
    --  money_limit_locked = 0.0,
    --  money_limit_locked_nonmarginal_value = 0.0,
    --  money_current_balance = 296936.38,
    --  money_current_limit = 0.0,
    -- }

    initConfig()

    -- Брать из money_limit_available (тут лучше - доступное количество) или money_current_balance (текущий баланс)
    --local money = getMoney(getConfigValue("CLIENT_CODE"), getConfigValue("FIRM_ID"), getConfigValue("TAG"), "SUR")
    local money = getMoney(getConfigValue("CLIENT_CODE"), getConfigValue("FIRM_ID"), getConfigValue("TAG"), "SUR")
    local money = getMoney(getConfigValue("CLIENT_CODE"), getConfigValue("FIRM_ID"), getConfigValue("TAG"), "SUR")

    log("Money: " .. tableToString(money))

    log('ALLOW_SHORTS: ' .. (tostring(getConfigValue('ALLOW_SHORTS') == '1')))

    updatePositionData()
    process()

    while true do
        sleep(1)

        if isTradingPaused() then
            sleep(10000)
            pauseTrading(false)
        end
    end
end

function OnParam(class, sec)
    if class == getConfigValue("CLASS_CODE") and sec == getConfigValue("SEC_CODE") then
        collectTrendData(class, sec)
        process()
    end
end

function OnTransReply(trans)
    log("OnTransReply: " .. tableToString(trans))
end

-- Функция вызывается терминалом QUIK при получении изменений лимита по бумагам
function OnDepoLimit(dlimit)
    updatePositionData()
end

function updatePositionData()
    local depo = getDepoEx(getConfigValue("FIRM_ID"), getConfigValue("CLIENT_CODE"), getConfigValue("SEC_CODE"), getConfigValue("TRADING_ACCOUNT_ID"), 0)

    log("Depo: " .. tableToString(depo))

    PositionData["awg_price"] = depo["awg_position_price"]
    PositionData["count"] = math.floor(depo["currentbal"])

    -- 03-08-2021 02:00:10.312: Depo: {
    -- wa_position_price = 306.3,
    --  client_code = "10427",
    --  currentbal = 10.0, - текущий остаток по бумаге (ВОТ ЭТО И НУЖНО)
    --  limit_kind = 0, - 0 = T0, 1 = T1, 2 =T2
    --  awg_position_price = 306.3, - цена приобретения (ЭТО ТОЖЕ НУЖНО)
    --  trdaccid = "NL0011100043", -- счет депо
    --  locked_sell = 0.0, - заблокировано на продажу количество лотов
    --  locked_sell_value = 0.0, - стоимость ценных бумаг, заблокированны под продажу
    --  locked_buy = 0.0, - заблокировано на покупку количество лотов
    --  locked_buy_value = 0.0, - стоимость ценных бумаг, заблокированных под покупку
    --  firmid = "NC0011100000",
    --  currentlimit = 0.0, - текущий лимит по бамаге
    --  openlimit = 0.0,
    --  sec_code = "SBER",
    --  openbal = 0.0,
    -- }
end

function getParams(classCode, secCode)
    -- @todo Данная функция не нужна, надо её выпилить

    local bidCount = getParamEx(classCode, secCode, "bid_count")
    local bid = getParamEx(classCode, secCode, "bid")
    local offerCount = getParamEx(classCode, secCode, "offet_count")
    local offer = getParamEx(classCode, secCode, "offer")
    local lotsize = getParamEx(classCode, secCode, "lotsize")

    -- quotes = getQuoteLevel2(classCode, secCode)

    --param_type STRING Тип данных параметра, используемый в Таблице текущих торгов. Возможные значения: 
    --    «1» - DOUBLE;
    --    «2» - LONG; 
    --    «3» - CHAR; 
    --    «4» - перечислимый тип; 
    --    «5» - время; 
    --    «6» - дата 

    -- param_value STRING Значение параметра. Для param_type = 3 значение параметра равно «0», в остальных случаях – числовое представление. Для перечислимых типов значение равно порядковому значению перечисления  
    -- param_image STRING Строковое значение параметра, аналогичное его представлению в таблице. В строковом представлении учитываются разделители разрядов, разделители целой и дробной части. Для перечислимых типов выводятся соответствующие им строковые значения  
    -- result STRING Результат выполнения операции. Возможные значения: 
    --    «0» - ошибка; 
    --    «1» - параметр найден  

    return {
        bid_price = bid["param_value"],
        offer_price = offer["param_value"],
        lot_size = math.ceil(lotsize["param_value"]),
    }
end

function process()
    if isTradingPaused() then
        log("Ничего не делаем, торговля на паузе")
        return
    end

    local params = getParams(getConfigValue("CLASS_CODE"), getConfigValue("SEC_CODE"))
    local profitTotalAmount = params["bid_price"] * PositionData["count"] - PositionData["awg_price"] * PositionData["count"]
    local brokerComissionAmount = math.abs(params["bid_price"] * PositionData["count"] * tonumber(getConfigValue("BROKER_COMISSION_FACTOR")) * 2) -- *2 здесь - т.к. комиссия есть и за покупку, и за продажу

    local priceDiff = params["bid_price"] - PositionData["awg_price"]

    log("Спрос: " .. round(params["bid_price"], 2) .. ", предложение: " .. round(params["offer_price"], 2) .. ", штук в лоте: " .. math.ceil(params["lot_size"]))
    log("Цена покупки позиции: " .. round(PositionData["awg_price"], 2) .. ", priceDiff: " .. round(priceDiff , 2).. ", profitTotalAmount: " .. round(profitTotalAmount, 2) .. ", brokerComissionAmount: " .. round(brokerComissionAmount, 2) ..
        ", DECISION_VALUES: " .. getConfigValue("DECISION_POSITIVE_VALUE") .. "/-" .. getConfigValue("DECISION_NEGATIVE_VALUE") .. ", прибыль: " .. round(profitTotalAmount - brokerComissionAmount, 2))

    if PositionData["count"] > 0 and (math.floor(params["bid_price"]) < 1 or math.floor(PositionData["awg_price"]) < 1) then
        log("Неконсистентные данные, ничего не делаем: " .. tableToString(params) .. ", " .. tableToString(PositionData))
        return
    end

    if PositionData["count"] > 0 then
        if priceDiff > 0 then
            -- Цена увеличилась, прибыль при продаже
            if  profitTotalAmount - brokerComissionAmount >= tonumber(getConfigValue("DECISION_POSITIVE_VALUE")) then
                log("Надо продавать, получим чистую прибыль: " .. round(profitTotalAmount - brokerComissionAmount, 2))
                sendOrder(OrderTypeSell, math.floor(PositionData["count"] / params["lot_size"]))
            end
        elseif priceDiff < 0 then
            -- Цена уменьшилась, фиксируем убыток
            if  math.abs(profitTotalAmount - brokerComissionAmount) >= tonumber(getConfigValue("DECISION_NEGATIVE_VALUE")) then
                log("Надо продавать и фиксировать убыток: " .. round(math.abs(profitTotalAmount - brokerComissionAmount), 2))
                sendOrder(OrderTypeSell, math.floor(PositionData["count"] / params["lot_size"]))
            end
        end
    elseif PositionData["count"] < 0 then
        -- Шортили и позиция в минусе
        if priceDiff > 0 then
            -- Цена поднялась, для шортов это убыток при покупке
            if  math.abs(profitTotalAmount - brokerComissionAmount) >= tonumber(getConfigValue("DECISION_NEGATIVE_VALUE")) then
                log("Надо покупать и фиксировать убыток: " .. round(math.abs(profitTotalAmount - brokerComissionAmount), 2))
                sendOrder(OrderTypeBuy, math.floor(PositionData["count"] / params["lot_size"]))
            end
        elseif priceDiff < 0 then
            -- Цена опустилась, прибыль при покупке
            if  math.abs(profitTotalAmount - brokerComissionAmount) >= tonumber(getConfigValue("DECISION_POSITIVE_VALUE")) then
                log("Надо покупать, получим чистую прибыль: " .. round(math.abs(profitTotalAmount - brokerComissionAmount), 2))
                sendOrder(OrderTypeBuy, math.floor(PositionData["count"] / params["lot_size"]))
            end
        end
    elseif PositionData["count"] == 0 then
        local trendType = getTrendType()
        if trendType == TrendTypeBull then
            -- При восходящем тренде покупаем
            sendOrder(OrderTypeBuy, math.floor(tonumber(getConfigValue("BUY_LOT_QUANTITY"))))
        elseif trendType == TrendTypeBear and getConfigValue('ALLOW_SHORTS') == '1' then
            -- При нисходящем тренде продаём, если в конфиге включена возможность шортов
            sendOrder(OrderTypeSell, math.floor(tonumber(getConfigValue("BUY_LOT_QUANTITY"))))
        end
    end
end

function sendOrder(orderType, quantity)
    log("Отправляем заявку на " .. (orderType == OrderTypeBuy and "покупку" or "продажу") .. " " .. quantity .. " лотов")

    result = sendTransaction({
        ACCOUNT = getConfigValue("TRADING_ACCOUNT_ID"),
        CLIENT_CODE = getConfigValue("CLIENT_CODE"),
        CLASSCODE = getConfigValue("CLASS_CODE"),
        SECCODE = getConfigValue("SEC_CODE"),
        EXECUTION_CONDITION = "FILL_OR_KILL", -- Исполнить немедленно или отклонить. По-умолчанию - поставить в очередь
        TYPE = "M", -- L - лимитированная (limit), M - рыночная (market)
        TRANS_ID = tostring(math.floor(1000 * os.clock())), -- От 1 до 2 147 483 647, порядковый номер
        ACTION = "NEW_ORDER",
        OPERATION = orderType, -- S - продать (sell), B - купить (buy)
        PRICE = "0",
        QUANTITY = tostring(quantity)
    })

    if orderType == OrderTypeBuy then
        PositionData["count"] = quantity
    else
        PositionData["count"] = 0 -- Чтобы нельзя было снова продать и уйти в минус
    end

    log("Результат отправки заявки: " .. result)

    pauseTrading(true)
end

function pauseTrading(pause)
    PauseTrading = pause;
end

function isTradingPaused()
    return PauseTrading
end
