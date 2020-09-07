require_relative 'constantExpression.class'

class Type

	def self.newBool
		Type.new(:bool)
	end

	def self.newInt
		Type.new(:int)
	end

	def self.newFloat
		Type.new(:float)
	end
	
	def initialize(primType, x = 0, y = 0, id = "")
		@type = primType
		@xDim = x
		@yDim = y
		@id = id
	end

	def ==(o)
		@type == o.typeSymbol && @xDim == o.x && @yDim == o.y && @id == o.id
	end

	def typeSymbol
		@type
	end

	def x
		@xDim
	end

	def y
		@yDim
	end

	def id
		@id
	end

	def isBool
		@type == :bool
	end

	def isInt
		@type == :int
	end

	def isFloat
		@type == :float
	end

	def isRecord
		@type == :record
	end

	def isNumber
		@type == :int || @type == :float
	end

	def isVector
		@type == :intvec || @type == :floatvec
	end

	def isMatrix
		@type == :intmat || @type == :floatmat
	end

	def isVoid
		@type == :void
	end

	def elemType
		if @type == :intmat || @type == :intvec
			return Type.new(:int)
		elsif @type == :floatmat || @type == :floatvec
			return Type.new(:float)
		else
			return self
		end
	end

	def vecType(size)
		if @type == :int || @type == :intvec || @type == :intmat
			return Type.new(:intvec, size)
		elsif @type == :float || @type == :floatvec || @type == :floatmat
			return Type.new(:floatvec, size)
		else
			return self
		end
	end

	def matType(x, y)
		if @type == :int || @type == :intvec || @type == :intmat
			return Type.new(:intmat, x, y)
		elsif @type == :float || @type == :floatvec || @type == :floatmat
			return Type.new(:floatmat, x, y)
		else
			return self
		end
	end

	def toString
		case @type
		when :int
			return "int"
		when :float
			return "float"
		when :bool
			return "bool"
		when :string
			return "string"
		when :void
			return "void"
		when :intvec
			return "vector <int> [#{ConstantExpression::generate(@xDim)}]"
		when :floatvec
			return "vector <float> [#{ConstantExpression::generate(@xDim)}]"
		when :intmat
			return "matrix <int> [#{ConstantExpression::generate(@xDim)}][#{ConstantExpression::generate(@yDim)}]"
		when :floatmat
			return "matrix <float> [#{ConstantExpression::generate(@xDim)}][#{ConstantExpression::generate(@yDim)}]"
		when :record
			return @id
		end
	end
end