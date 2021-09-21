local Recycler = {}
Recycler.__index = Recycler

local WeakMetatable = {__mode = "v"}

function Recycler.new()
	return setmetatable({
		_destroyed = false,
		_recycled = {
			-- Recycler respects this order:

			{}, -- strong objects (won't get g-collected)
			setmetatable(
				{},  -- weak objects (can still be g-collected)
				WeakMetatable
			)
		},

		_onDestroyed = nil,
		_onNewObject = nil,
	}, Recycler)
end

function Recycler:GetObject()
	if self._destroyed then
		return nil
	end

	local onNewObject = self._onNewObject
	local onDestroyed = self._onDestroyed

	for _, storage in ipairs(self._recycled) do
		local index, object = next(storage)

		if object ~= nil then
			storage[index] = nil

			if onDestroyed then
				onDestroyed(object)
			end

			return object
		end
	end

	-- No garbage found:
	if onNewObject then
		return onNewObject()
	end
end

function Recycler:GetObjects(
	objectCount: number,
	createNewObjects: boolean?
)
	assert(
		typeof(objectCount) == "number",
		"You must specify an object count on :GetObjects!"
	)

	createNewObjects = createNewObjects == nil
		and true
		or createNewObjects

	if self._destroyed then
		return
	end

	local onDestroyed = self._onDestroyed
	local onNewObject = self._onNewObject

	local objects = table.create(onNewObject and objectCount or 1)
	local objectsLeft = objectCount

	for _, storage in ipairs(self._recycled) do
		local index, object = next(storage)

		while objectsLeft > 0 and object ~= nil do
			storage[index] = nil

			if onDestroyed then
				onDestroyed(object)
			end

			table.insert(objects, object)
		end
	end

	if onNewObject and createNewObjects then
		for _ = 1, objectsLeft do
			local object = onNewObject()

			if object then
				table.insert(objects, object)
			end
		end
	end

	return objects
end

local function AddToGarbage(self, binId, ...)
	local argCount = select("#", ...)
	if argCount == 0 then
		error("You need to add at least one item!", 2)
	end

	if argCount == 1 then
		table.insert(
			self._recycled[binId],
			...
		)
	else
		local args = {...}
		for _, item in ipairs(args) do
			table.insert(
				self._recycled[binId],
				item
			)
		end
	end
end

function Recycler:AddToGarbage(...)
	if self._destroyed then
		return self
	end

	AddToGarbage(self, 2, ...)

	return self
end

-- :AddToStrongGarbage keeps whatever item you passed through it, on a
-- table which isn't weak, it will never be garbage collected, unless you clear
-- the recycler, or if :GetObject returns an item from strong garbage.
function Recycler:AddToStrongGarbage(...)
	if self._destroyed then
		return self
	end

	AddToGarbage(self, 1, ...)

	return self
end

-- :OnDestroyed sets the handler which will be called whenever there is some garbage you can re-use,
-- This allows it to reset parts of an item, to default, for instance, before
-- such object is returned by :GetObject!
function Recycler:OnDestroyed(
	handler: (object: any) -> ()
)
	assert(
		typeof(handler) == "function",
		":OnDestroyed must be called with a function"
	)

	if self._destroyed then
		return self
	end

	self._onDestroyed = handler

	return self
end

-- :OnNewObject sets the handler which will be called whenever there is no garbage to re-use,
-- Whatever it returns will be returned on :GetObject!
function Recycler:OnNewObject(
	handler: () -> (any)
)
	assert(
		typeof(handler) == "function",
		":OnNewObject must be called with a function"
	)

	if self._destroyed then
		return self
	end

	self._onNewObject = handler

	return self
end

-- :Clear only clears any references for garbage that a recycler has.
-- The recycler object can still be used after this was called on it.
function Recycler:Clear(dontReUseTable: boolean?)
	if self._destroyed then
		return self
	end

	if dontReUseTable then
		self._recycled = {
			{},
			setmetatable(
				{},
				WeakMetatable
			)
		}
	else
		for _, storage in ipairs(self._recycled) do
			table.clear(storage)
		end
	end

	return self
end

-- :Destroy destroys the recycler object,
-- cleaning up any references to functions or to any garbage.
-- This function makes the recycler object unusable.
-- Only use it if you don't need it anymore.
function Recycler:Destroy()
	if self._destroyed then
		return self
	end

	self._destroyed = true

	self._recycled = nil
	self._onDestroyed = nil
	self._onNewObject = nil

	return self
end

export type Class = typeof(
	setmetatable({}, Recycler)
)

return Recycler
