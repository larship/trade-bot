require("helper")

ClassCode = "QJSIM"
SecCode = "SBER"

ClientCode = "10427" -- Тестовый код клиента
FirmId = "NC0011100000" -- NC0011100000 - фондовая биржа, SPBFUT000000 - срочный рынок, MB1000100000 - валютный рынок
Tag = "EQTV" -- EQTV, USDR, RTOD, RTOM
TradingAccountId = "NL0011100043" -- Счет депо

BrokerComissionFactor = 0.0006 -- Процент комиссии брокера за каждую операцию - 0.06%

BuyLotQuantity = 10
DecisionValue = 100 -- Количество денег, которые мы хотим заработать с каждой сделки
DecisionSellFactor = 0.5 -- Множитель для решения о продаже

PositionData = {
    awg_price = 0,
    count = 0
}

PauseTrading = false

TradeTypeBuy = "B"
TradeTypeSell = "S"

function main()
    log("Запускаем скрипт, " .. _VERSION)

    -- Брать из money_limit_available (тут лучше - доступное количество) или money_current_balance (текущий баланс)
    local money = getMoney(ClientCode, FirmId, Tag, "SUR")
    log("Money: " .. tableToString(money))

    -- 04-08-2021 11:24:10.358: Money: {
    --  money_open_balance = 296936.38,
    --  money_open_limit = 0.0,
    --  money_limit_available = 296936.38,
    --  money_limit_locked = 0.0,
    --  money_limit_locked_nonmarginal_value = 0.0,
    --  money_current_balance = 296936.38,
    --  money_current_limit = 0.0,
    -- }

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
    if class == ClassCode and sec == SecCode then
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
    local depo = getDepoEx(FirmId, ClientCode, SecCode, TradingAccountId, 0)
    PositionData["awg_price"] = depo["awg_position_price"]
    PositionData["count"] = math.floor(depo["currentbal"])

    log("Depo: " .. tableToString(depo))

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
    bidCount = getParamEx(classCode, secCode, "bid_count")
    bid = getParamEx(classCode, secCode, "bid")
    offerCount = getParamEx(classCode, secCode, "offet_count")
    offer = getParamEx(classCode, secCode, "offer")
    lotsize = getParamEx(classCode, secCode, "lotsize")

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

    log("Спрос: " .. bid["param_value"] .. ", предложение: " .. offer["param_value"] .. ", штук в лоте: " .. math.ceil(lotsize["param_value"]))

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

    -- Вначале надо проверить, есть ли у нас купленная позиция
    --     Если позиции нет - просто покупаем
    --     Если позиция есть:
    --         Если цена поднялась достаточно (коэффициент 1) - продаём, получаем прибыль
    --         Если цена опустилась достаточно (коэффициент 0.3) - продаём, получаем убыток
    --         Если цена поднялась или опустилась недостаточно - ничего не делаем

    -- Также надо ввести дополнительные проверки:
    -- Например, каждые минуту / пять минут проверять цену, если она падает сколько то раз подряд - алертить и вообще не торговать
    -- Потому-что данный бот пока-что не умеет торговать в прибыль при падении

    local params = getParams(ClassCode, SecCode)
    local profitTotalAmount = params["bid_price"] * PositionData["count"] - PositionData["awg_price"] * PositionData["count"]
    local brokerComissionAmount = math.abs(params["bid_price"] * PositionData["count"] * BrokerComissionFactor)

    local priceDiff = params["bid_price"] - PositionData["awg_price"]
    log("Цена покупки позиции: " .. PositionData["awg_price"] .. ", priceDiff: " .. priceDiff .. ", profitTotalAmount: " .. profitTotalAmount .. ", brokerComissionAmount: " .. brokerComissionAmount ..
        ", DecisionValue: " .. DecisionValue .. "/-" .. DecisionValue * DecisionSellFactor .. ", прибыль: " .. profitTotalAmount - brokerComissionAmount)

    if PositionData["count"] > 0 then
        if math.floor(params["bid_price"]) < 1 or math.floor(PositionData["awg_price"]) < 1 then
            log("Неконсистентные данные, ничего не делаем: " .. tableToString(params) .. ", " .. tableToString(PositionData))
            return
        end

        if priceDiff > 0 then
            -- Цена увеличилась, прибыль при продаже
            if  profitTotalAmount - brokerComissionAmount >= DecisionValue then
                -- @todo Тут надо продавать позицию
                log("Надо продавать, получим чистую прибыль: " .. profitTotalAmount - brokerComissionAmount)

                sendOrder(TradeTypeSell, math.floor(PositionData["count"] / params["lot_size"]))
            else
               -- log("Не продаём, т.к. не будет получено требуемое значение прибыли: " .. profitTotalAmount .. " - " .. brokerComissionAmount ..
                 --   " = " .. (profitTotalAmount - brokerComissionAmount) .. " < " .. DecisionValue)
            end
        elseif priceDiff < 0 then
            -- Цена уменьшилась, фиксируем убыток
             if  math.abs(profitTotalAmount - brokerComissionAmount) >= DecisionValue * DecisionSellFactor then
                log("Надо продавать и фиксировать убыток: " .. math.abs(profitTotalAmount - brokerComissionAmount))
                sendOrder(TradeTypeSell, math.floor(PositionData["count"] / params["lot_size"]))

                -- @todo Сделать фикс для нулевой цены. Запись из лога:
                -- 10-08-2021 9:03:02.470: params: {
                --  bid_price = "0.000000",
                --  offer_price = "0.000000",
                -- }
                -- 10-08-2021 9:03:02.470: priceDiff: -319,01
                -- 10-08-2021 9:03:02.470: profitTotalAmount, brokerComissionAmount, DecisionValue: -3190,1, 0,0, 50
                -- 10-08-2021 9:03:02.470: Надо продавать и фиксировать убыток: 3190,1
             end
        end
    else
        -- @todo Тут надо покупать позицию. Также возможно сюда прикрутить стратегию на понижение
        log("Надо покупать позицию, потому-что её нет")
        sendOrder(TradeTypeBuy, BuyLotQuantity)
    end
end

function sendOrder(tradeType, quantity)
    log("Отправляем заявку на " .. (tradeType == TradeTypeBuy and "покупку" or "продажу") .. " " .. quantity .. " лотов")

    result = sendTransaction({
        ACCOUNT = TradingAccountId,
        CLIENT_CODE = ClientCode,
        CLASSCODE = ClassCode,
        SECCODE = SecCode,
        EXECUTION_CONDITION = "FILL_OR_KILL", -- Исполнить немедленно или отклонить. По-умолчанию - поставить в очередь
        TYPE = "M", -- L - лимитированная (limit), M - рыночная (market)
        TRANS_ID = tostring(math.floor(1000 * os.clock())), -- От 1 до 2 147 483 647, порядковый номер
        ACTION = "NEW_ORDER",
        OPERATION = tradeType, -- S - продать (sell), B - купить (buy)
        PRICE = "0",
        QUANTITY = tostring(math.floor(quantity))
    })

    if tradeType == TradeTypeBuy then
        PositionData["count"] = math.floor(BuyLotQuantity)
        --log("PositionData: " .. tableToString(PositionData))
    else
        PositionData["count"] = 0 -- Чтобы нельзя было снова продать и уйти в минус
        --log("PositionData: " .. tableToString(PositionData))
    end

    log("Результат отправки заявки: " .. result)
    --message("RESULT: " .. result)

    pauseTrading(true)
end

function pauseTrading(pause)
    PauseTrading = pause;
end

function isTradingPaused()
    return PauseTrading
end
