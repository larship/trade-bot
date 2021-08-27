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

    if #TrendData > 0 and bid["param_value"] == TrendData[#TrendData] then
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
        local headAvg = getTableSum(TrendData, 1, 3) / 3
        local tailAvg = getTableSum(TrendData, #TrendData - 2, 3) / 3

        log("headAvg: " .. headAvg .. ", tailAvg: " .. tailAvg .. ", abs: " .. math.abs(headAvg - tailAvg) .. ", neutralVal: " .. headAvg * NeutralTrendFactor)
    
        -- Если разница меньше определённого процента - считаем тренд боковым
        if math.abs(headAvg - tailAvg) < headAvg * NeutralTrendFactor then
            log('TrendTypeNeutral')
            return TrendTypeNeutral
        end

        if headAvg < tailAvg then
            log('TrendTypeBull')
            return TrendTypeBull
        end

        log('TrendTypeBear')
        return TrendTypeBear
    end

    log('TrendTypeUnknown')
    return TrendTypeUnknown
end
