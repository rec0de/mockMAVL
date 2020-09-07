class ConstantExpression

	def self.generate(value)
		if Random::rand() < 0.3
			if Random::rand() < 0.5
				a = (Random::rand()*15).to_i
				b = value - a
				return "#{self.generate(a)} + #{self.mulDiv(b)}"
			else
				a = (Random::rand()*15).to_i
				b = value + a
				return "#{self.generate(b)} - #{self.mulDiv(a)}"
			end
		else
			return self.mulDiv(value)
		end
	end

	def self.mulDiv(value)
		if Random::rand() < 0.3
			# Build multiplication
			if Random::rand() < 0.5
				factors = (1..(value.abs ** 0.5).to_i).select{ |n| value % n == 0}
				if factors.length > 0
					a = factors.sample
					b = value / a
					return "#{self.mulDiv(a)} * #{self.unaryMinus(b)}"
				else
					return self.unaryMinus(value)
				end				
			# Build division
			else
				a = (Random::rand() * 5).to_i + 1
				b = value * a
				return "#{self.mulDiv(b)} / #{self.unaryMinus(a)}"
			end
		else
			return self.unaryMinus(value)
		end
	end

	def self.unaryMinus(value)
		if value < 0
			return "-#{self.exponentiation(-value)}"
		else
			return self.exponentiation(value)
		end
	end

	def self.exponentiation(value)
		if Random::rand() < 0.2 && value >= 4
			bases = (2..(value ** 0.5).to_i).select{ |n| n ** Math::log(value, n).to_i == value}
			if bases.length > 0
				a = bases.sample
				b = Math::log(value, a).to_i
				return "#{self.atom(a)} ^ #{self.exponentiation(b)}"
			else
				return self.atom(value)
			end
		else
			return self.atom(value)
		end
	end

	def self.atom(value)
		if Random::rand() < 0.07
			return "(#{self.generate(value)})"
		else
			return value.to_s
		end
	end
end