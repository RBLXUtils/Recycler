local Recycler = {}
Recycler.__index = Recycler

local WeakMetatable = {__mode = 'v'}

function Recycler.new()
	return setmetatable({
		_destroyed = false,
		_garbage = setmetatable({}, WeakMetatable),
		_onDestroyed = nil,
		_onNewObject = nil
	}, Recycler)
end

function Recycler:GetObject()
	if self._destroyed then
		return
	end

	local _garbage = self._garbage
	do
		local index, object = next(_garbage)

		if object ~= nil then
			_garbage[index] = nil

			local onDestroyed = self._onDestroyed
			if onDestroyed then
				onDestroyed(object)
			end

			return object
		end
	end

	local onNewObject = self._onNewObject
	if onNewObject then
		return onNewObject()
	end
end

function Recycler:AddToGarbage(item)
	if self._destroyed then
		return self
	end

	table.insert(
		self._garbage,
		item
	)

	return self
end

function Recycler:OnDestroyed(handler)
	-- The handler will be called whenever there is some garbage you can re-use,
	-- This allows it to reset parts of an item, to default, for example.

	if self._destroyed then
		return self
	end

	assert(
		typeof(handler) == 'function',
		":OnDestroyed must be called with a function"
	)

	self._onDestroyed = handler

	return self
end

function Recycler:OnNewObject(handler)
	-- The handler will be called whenever there is no garbage to re-use,
	-- Whatever it returns will be returned on :getObject!

	if self._destroyed then
		return self
	end

	assert(
		typeof(handler) == 'function',
		":OnNewObject must be called with a function"
	)

	self._onNewObject = handler

	return self
end

function Recycler:Clear()
	if self._destroyed then
		return self
	end

	table.clear(self._garbage)

	return self
end

function Recycler:Destroy()
	if self._destroyed then
		return self
	end

	self._destroyed = true

	self._garbage = nil
	self._onDestroyed = nil
	self._onNewObject = nil
end

return Recycler
