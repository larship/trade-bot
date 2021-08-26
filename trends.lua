local TrendData = {}
local TrendTypeBull = "Bull" -- Восходящий тренд
local TrendTypeBear = "Bear" -- Нисходящий тренд
local TrendTypeNeutral = "Neutral" -- Нейтральный (боковой) тренд
local TrendTypeUnknown = "Unknown" -- Тренд неизвестен

local MaxTrendDataSize = 100
local TrendSizeForComputing = 10
local NeutralTrendFactor = 0.0005 -- 0.0025

function collectTrendData(classCode, secCode)
    local bid = getParamEx(classCode, secCode, "bid")

    if bid["param_value"] == TrendData[#TrendData] then
        return
    end

    table.insert(TrendData, bid["param_value"])

    -- @todo Возможно, тут лучше ориентироваться на время, а не на количество
    if #TrendData > MaxTrendDataSize then
        table.remove(TrendData, 1)
    end

    log("TrendData:" .. tableToString(TrendData))
end

function getTrendType()
    if #TrendData >= TrendSizeForComputing then
        local headSum = getTableSum(TrendData, 1, 3)
        local tailSum = getTableSum(TrendData, #TrendData - 2, 3)

        log("headSum: " .. headSum .. ", tailSum: " .. tailSum .. ", abs: " .. math.abs(headSum - tailSum) .. ", neutralVal: " .. headSum * NeutralTrendFactor)
    
        -- Если разница меньше определённого процента - считаем тренд боковым
        if math.abs(headSum - tailSum) < headSum * NeutralTrendFactor then
            return TrendTypeNeutral
        end

        if headSum < tailSum then
            return TrendTypeBull
        end

        return TrendTypeBear
    end

    return TrendTypeUnknown
end
