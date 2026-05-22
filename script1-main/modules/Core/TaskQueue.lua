--// Task Queue Module
--// Manages autofarm task queue

local TaskQueue = {}

function TaskQueue.Init()
    local currentAutofarmTask = nil
    local autofarmTaskQueue = {}

    local function queueAutofarmTask(taskType, pet)
        table.insert(autofarmTaskQueue, {type = taskType, pet = pet})
        if not currentAutofarmTask then
            return true -- should execute next
        end
        return false
    end

    local function getNextTask()
        if #autofarmTaskQueue == 0 then
            currentAutofarmTask = nil
            return nil
        end
        local task = table.remove(autofarmTaskQueue, 1)
        currentAutofarmTask = task
        return task
    end

    local function clearQueue()
        autofarmTaskQueue = {}
        currentAutofarmTask = nil
    end

    local function getCurrentTask()
        return currentAutofarmTask
    end

    local function getQueueSize()
        return #autofarmTaskQueue
    end

    return {
        queueAutofarmTask = queueAutofarmTask,
        getNextTask = getNextTask,
        clearQueue = clearQueue,
        getCurrentTask = getCurrentTask,
        getQueueSize = getQueueSize,
    }
end

return TaskQueue
