local Recycler = {}
Recycler.__index = Recycler

local WeakMetatable = {__mode = 'v'}

function Recycler.new()
	return setmetatable({
		_destroyed = false,
		_garbage = setmetatable({}, WeakMetatable),
		_strong_garbage = {},
		_onDestroyed = nil,
		_onNewObject = nil
	}, Recycler)
end

function Recycler:GetObject()
	if self._destroyed then
		return
	end

	local _strong_garbage = self._strong_garbage
	local _garbage = self._garbage
	do
		local index, object = next(_strong_garbage)

		if object ~= nil then
			-- There is a strong reference object we can use!
			_strong_garbage[index] = nil
		else
			index, object = next(_garbage)

			if object ~= nil then
				-- There is a weak reference object we can use!
				_garbage[index] = nil
			end
		end

		if object ~= nil then
			local onDestroyed = self._onDestroyed
			if onDestroyed then
				onDestroyed(object)
			end

			return object
		end
	end
	
	-- No garbage found:
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

-- :AddToStrongGarbage keeps whatever item you passed through it, on a
-- table which isn't weak, it will never be garbage collected, unless you clear
-- the recycler, or if :GetObject returns an item from strong garbage.
function Recycler:AddToStrongGarbage(item)
	if self._destroyed then
		return self
	end

	table.insert(
		self._strong_garbage,
		item
	)

	return self
end

-- :OnDestroyed sets the handler which will be called whenever there is some garbage you can re-use,
-- This allows it to reset parts of an item, to default, for instance, before
-- such object is returned by :GetObject!
function Recycler:OnDestroyed(handler)	
	assert(
		typeof(handler) == 'function',
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
function Recycler:OnNewObject(handler)
	assert(
		typeof(handler) == 'function',
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
function Recycler:Clear()
	if self._destroyed then
		return self
	end

	table.clear(self._garbage)
	table.clear(self._strong_garbage)

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

	self._garbage = nil
	self._strong_garbage = nil
	self._onDestroyed = nil
	self._onNewObject = nil

	return self
end

return Recycler
