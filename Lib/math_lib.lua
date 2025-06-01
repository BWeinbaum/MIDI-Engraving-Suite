-- Library for math functions and classes (static).
local cmath = {}

--- Function to calculate the greatest common divisor (GCD)
--- @param a integer
--- @param b integer
--- @return integer
function cmath.GCD(a, b)
    while b ~= 0 do
        a, b = b, a % b
    end
    return math.abs(a)
end

--- Function to calculate the least common multiple (LCM).
--- @param a integer
--- @param b integer
--- @return integer
function cmath.LCM(a, b)
    return math.abs(a * b) // gcd(a, b)
end

--- Converts a decimal number input into a hexidecimal string output
--- @param decimal integer
--- @return string
function cmath.DecimalToHex(decimal)
    local hexChars = "0123456789ABCDEF"
    local hex = ""
    while decimal > 0 do
        local remainder = decimal % 16
        hex = hexChars:sub(remainder + 1, remainder + 1) .. hex
        decimal = math.floor(decimal / 16)
    end
    return hex == "" and "0" or '0x'..hex
end

--- Converts a hexidecimal string input into a decimal number output.
--- @param hex string
--- @return integer
function cmath.HexToDecimal(hex)
    hex = string.gsub(hex, '0x', '')
    local hexChars = "0123456789ABCDEF"
    local decimal = 0
    local length = #hex
    for i = 1, length do
        local char = hex:sub(i, i):upper()
        local value = hexChars:find(char) - 1
        decimal = decimal * 16 + value
    end
    return decimal
end

--- Determines if a string input can be converted to a decimal integer.
--- @param value string|number
--- @return boolean
function cmath.IsInteger(value)
    if type(value) == "number" and math.floor(value) == value then
        return true
    elseif type(value) == "string" then
        local trimmedValue = value:match("^%s*(.-)%s*$") -- Trim leading and trailing spaces
        return trimmedValue ~= "" and not (trimmedValue:find("^%-?%d+$") == nil)
    end
    return false
end

--- Determines if a string input contains only hexidecimal digits
--- @param str string
--- @return boolean
function cmath.IsHexadecimal(str)
    return str:match("^[%x]+$") ~= nil
end

--- Returns an integer if the input parameter is a string that can be converted to an integer
--- or if the input is a number that is an integer. Otherwise, returns nil.
--- @param input string|number
--- @return integer?
function cmath.GetInteger(input)
    if cmath.IsInteger(input) then
        return tonumber(input)
    end
end


--- @class Fraction
--- @field numerator integer
--- @field denominator integer
--- @field reduce boolean
cmath.Fraction = {}
cmath.Fraction.__index = Fraction

--- Constructor for creating a new fraction.
--- @param numerator integer
--- @param denominator integer
--- @param reduce? boolean
--- @return Fraction
function cmath.Fraction.New(numerator, denominator, reduce)
    reduce = reduce or false
    local self = setmetatable({}, Fraction)
    self.numerator = numerator
    self.denominator = denominator
    if reduce then self:reduce() end
    return self
end

-- Function to reduce the fraction to its simplest form.
function cmath.Fraction:Reduce()
    local common_divisor = gcd(self.numerator, self.denominator)
    self.numerator = self.numerator // common_divisor
    self.denominator = self.denominator // common_divisor
end

--- Function to add two fractions. Adds the fraction being called with [other].
--- @param other Fraction
--- @return Fraction
function cmath.Fraction:Add(other)
    local new_numerator = self.numerator * other.denominator + other.numerator * self.denominator
    local new_denominator = self.denominator * other.denominator
    return Fraction:New(new_numerator, new_denominator)
end

--- Function to multiply two fractions. Multiplies the fraction being called with [other].
--- @param other Fraction
--- @return Fraction
function cmath.Fraction:Multiply(other)
    local new_numerator = self.numerator * other.numerator
    local new_denominator = self.denominator * other.denominator
    return Fraction:New(new_numerator, new_denominator)
end

--- Function to convert a fraction to a string for easy printing.
--- @return string
function cmath.Fraction:__tostring()
    return string.format("%d/%d", self.numerator, self.denominator)
end

return cmath