require_relative 'scope.class'
require_relative 'type.class'
require_relative 'constantExpression.class'

class MockMAVL
	@@strings = ["fizz", "buzz", "foo", "bar", "Hello World!", "localhost", "127.0.0.1", "@tu-darmstadt.de"]

	def initialize
		@scope = Scope.new
		@records = RecordDefinitions.new
		@maxDimension = 6
	end

	def generateModule
		modules = []
		generatedMain = false

		Random::rand(1..10).times do
			if chance(0.2) && !generatedMain
				modules.push(generateMain())
				generatedMain = true
			end
			modules.push(chance(0.7) ? generateFunction() : generateRecordDecl())
		end

		if !generatedMain
			modules.push(generateMain())
		end

		return modules.join(' ')
	end

	def generateRecordDecl
		begin
			id = @scope.getFreeVarId(Type.new(:record))
		end while(@records.exists(id))

		declarations = []
		types = []
		names = []
		isVarFlags = []

		@scope.descend

		Random::rand(1..4).times do
			type = randomType(true) # do not generate records within records
			name = @scope.getFreeVarId(type)
			@scope.defineVar(name, type) # Hacky, just to avoid duplicate record entry names, cleared by scope exit
			isVar = chance(0.5)
			declarations.push(generateRecordElementDecl(type, name, isVar))
			types.push(type)
			names.push(name)
			isVarFlags.push(isVar)
		end

		@scope.exit

		@records.define(id, types, names, isVarFlags)

		return "record #{id} { #{declarations.join(' ')} } "
	end

	def generateRecordElementDecl(type, id, isVar)
		return "#{isVar ? 'var' : 'val'} #{type.toString} #{id} ;"
	end

	def generateFunction
		returnType = chance(0.7) ? randomType() : Type.new(:void)
		id = @scope.getFreeFuncId(returnType)

		# Generate random arguments
		args = []
		Random::rand(0..3).times do
			type = randomType()
			args.push(type)
		end

		# Define function and create new scope
		@scope.defineFunc(id, returnType, args)
		@scope.descend

		argList = args.map{ |arg|
			argname = @scope.getFreeVarId(arg)
			@scope.defineVar(argname, arg) # Define function parameters in function scope
			"#{arg.toString} #{argname}"
		}.join(', ')
		
		res = "function #{returnType.toString} #{id}(#{argList}) { "

		# Generate function body
		stmts = []
		Random::rand(0..7).times do
			stmts.push(generateStatement())
		end

		if !returnType.isVoid
			stmts.push(generateReturn(returnType))
		end

		stmts = stmts.join(" ")

		@scope.exit
		return res + stmts + " } "
	end

	def generateMain
		returnType = Type.new(:void)
		id = "main"
		args = []
		
		# Define function and create new scope
		@scope.defineFunc("main", Type.new(:void), [])
		@scope.descend

		res = "function void main() { "

		# Generate function body
		stmts = []
		Random::rand(0..7).times do
			stmts.push(generateStatement())
		end

		stmts = stmts.join(" ")

		@scope.exit
		return res + stmts + " } "
	end

	def generateStatement
		i = Random::rand(0..9)
		case i
		when (0..1)
			return generateValDef()
		when (2..3)
			return generateVarDecl()
		when 4
			return generateIf()
		when 5
			return generateCompound()
		when 6
			return generateAssignOrCall()
		when 7
			return generateSwitch()
		when 8
			return generateFor()
		when 9
			return generateForEach()
		end
	end

	def generateReturn(type)
		return "return #{generateExpr(type)} ;"
	end

	def generateVarDecl
		type = randomType()
		id = @scope.getFreeVarId(type)
		@scope.defineVar(id, type)
		return "var #{type.toString} #{id} ;"
	end

	def generateValDef
		type = randomType()
		id = @scope.getFreeVarId(type)
		@scope.defineVal(id, type)
		expr = generateExpr(type)
		return "val #{type.toString} #{id} = #{expr} ;"
	end

	def generateIf
		@scope.descend
		ifstmt = generateStatement()
		@scope.exit

		if chance(0.6)
			return "if (#{generateExpr(Type::newBool)}) #{ifstmt}"
		else
			@scope.descend
			elsestmt = generateStatement()
			@scope.exit
			return "if (#{generateExpr(Type::newBool)}) #{ifstmt} else #{elsestmt}"
		end
	end

	def generateCompound
		@scope.descend
		stmts = []
		Random::rand(0..5).times do
			stmts.push(generateStatement())
		end
		@scope.exit
		stmts = stmts.join(" ")
		return " { #{stmts} } "
	end

	def generateAssignOrCall
		obj = @scope.getVarOrFunc()
		if(obj.structureType == :var)
			return "#{generateAssign(obj.id, obj.dataType)} ; "
		else
			params = obj.arguments.map{ |arg| generateExpr(arg)}.join(', ')
			return "#{obj.id}(#{params}) ;"
		end
	end

	def generateAssign(id, type, simple = false)
		if type.isRecord && chance(0.3) && @records.recordHasVarElement(type.id) && !simple
			elemType, elemName = @records.randomVarElementOfRecord(type.id)
			return "#{id} @ #{elemName} = #{generateExpr(elemType)}"
		elsif type.isVector && chance(0.1) && !simple
			return "#{id}[#{generateExpr(Type::newInt)}] = #{generateExpr(type.elemType)}"
		elsif type.isMatrix && chance(0.1) && !simple
			return "#{id}[#{generateExpr(Type::newInt)}][#{generateExpr(Type::newInt)}] = #{generateExpr(type.elemType)}"
		else
			return "#{id} = #{generateExpr(type)}"
		end
	end

	def generateSwitch
		res = "switch (#{generateExpr(Type::newInt)}) { "
		cases = []
		basevalue = Random::rand(-100..100)
		scale = Random::rand(1..9)
		haveDefault = false

		Random::rand(0..5).times do |i|
			if chance(0.1) && !haveDefault
				cases.push(generateDefault())
				haveDefault = true
			else
				cases.push(generateCase(basevalue + i * scale)) # Ensure that constant expressions are unique
			end
		end

		return res + cases.join(' ') + " } "
	end

	def generateCase(value)
		@scope.descend
		stmt = generateStatement();
		@scope.exit()
		return "case #{ConstantExpression::generate(value)} : #{stmt}"
	end

	def generateDefault
		@scope.descend
		stmt = generateStatement();
		@scope.exit()
		return "default : #{stmt}"
	end

	def generateFor
		objA = @scope.getVar()
		objB = @scope.getVar()
		if objA == nil || objB == nil
			return generateVarDecl()
		else
			@scope.descend
			stmt = generateStatement()
			@scope.exit
			return "for(#{generateAssign(objA.id, objA.dataType, true)}; #{generateExpr(Type::newBool)};  #{generateAssign(objB.id, objB.dataType, true)}) #{stmt}"
		end
	end

	def generateForEach
		toIterate = @scope.getVectorOrMatrix()
		@scope.descend
		
		if toIterate != nil && chance(0.7)
			iteratorType = toIterate.dataType.elemType
			iteratorId = @scope.getFreeVarId(iteratorType)

			if toIterate.structureType == :var && chance(0.7)
				varval = "var"	
			else
				varval = "val"
			end

			toIterateExpr = toIterate.id
		else
			varval = "val"
			type = chance(0.7) ? Type.new([:intvec, :floatvec].sample, dimension()) : Type.new([:intmat, :floatmat].sample, dimension(), dimension())
			toIterateExpr = generateExpr(type)
			iteratorType = type.elemType
			iteratorId = @scope.getFreeVarId(iteratorType)
		end

		if varval == "val"
			@scope.defineVal(iteratorId, iteratorType)
		else
			@scope.defineVar(iteratorId, iteratorType)
		end
		res = "foreach(#{varval} #{iteratorType.toString} #{iteratorId} : #{toIterateExpr}) #{generateStatement()}"
		@scope.exit
		return  res
	end

	def generateExpr(type)
		generateSelect(type)
	end

	# Fully working
	def generateSelect(type)
		if chance(0.1)
			return "#{generateOr(Type::newBool)} ? #{generateOr(type)} : #{generateOr(type)}"
		else
			return generateOr(type)
		end
	end

	# Fully working
	def generateOr(type)
		if type.isBool && chance(0.3)
			return "#{generateAnd(type)} | #{generateOr(type)}"
		else
			return generateAddSub(type)
		end
	end

	# Fully working
	def generateAnd(type)
		if type.isBool && chance(0.2)
			return "#{generateNot(type)} & #{generateAnd(type)}"
		else
			return generateAddSub(type)
		end
	end

	# Fully working
	def generateNot(type)
		if type.isBool && chance(0.3)
			return "! #{generateCompare(type)}"
		else
			return generateAddSub(type)
		end
	end

	# Fully working
	def generateCompare(type)
		if type.isBool && chance(0.3)
			cmptype = Type.new([:int, :float].sample)
			cmpop = ["==", "<=", ">=", "!=", ">", "<"].sample
			return "#{generateAddSub(cmptype)} #{cmpop} #{generateAddSub(cmptype)}"
		else
			return generateAddSub(type)
		end
	end

	# Fully working
	def generateAddSub(type)
		if (type.isNumber || type.isVector || type.isMatrix) && chance(0.3)
			op = ["+", "-"].sample
			return "#{generateAddSub(type)} #{op} #{generateMulDiv(type)}"
		elsif (type.isVector || type.isMatrix) && chance(0.2)
			if chance(0.5)
				return "#{generateAddSub(type.elemType)} + #{generateMulDiv(type)}"
			else
				return "#{generateAddSub(type)} + #{generateMulDiv(type.elemType)}"
			end
		else
			return generateAtom(type)
		end
	end

	# Fully working
	def generateMulDiv(type)
		if (type.isNumber || type.isVector || type.isMatrix) && chance(0.3)
			op = type.isNumber ? ["*", "/"].sample : "*"
			return "#{generateMulDiv(type)} #{op} #{generateUnaryMinus(type)}"
		elsif (type.isVector || type.isMatrix) && chance(0.2)
			if chance(0.5)
				return "#{generateMulDiv(type.elemType)} * #{generateUnaryMinus(type)}"
			else
				return "#{generateMulDiv(type)} * #{generateUnaryMinus(type.elemType)}"
			end
		else
			return generateAtom(type)
		end
	end

	# Fully working
	def generateUnaryMinus(type)
		if type.isNumber && chance(0.2)
			return "- #{generateExponentiation(type)}"
		else
			return generateExponentiation(type)
		end
	end

	# Fully working
	def generateExponentiation(type)
		if (type.isNumber || type.isVector || type.isMatrix) && chance(0.3)
			return "#{generateDim(type)} ^ #{generateExponentiation(type)}"
		elsif (type.isVector || type.isMatrix) && chance(0.3)
			return "#{generateDim(type)} ^ #{generateExponentiation(type.elemType)}"
		else
			return generateDim(type)
		end
	end

	# Fully working
	def generateDim(type)
		if type.isInt && chance(0.1)
			xDim = dimension()
			yDim = dimension()
			if chance(0.5)
				entrytype = Type.new([:intvec, :floatvec].sample, xDim)
				return "#{generateDotProd(entrytype)} .dimension"
			else
				xy = [".rows", ".cols"].sample
				entrytype = Type.new([:intmat, :floatmat].sample, xDim, yDim)
				return "#{generateDotProd(entrytype)} #{xy}"
			end
		else
			return generateDotProd(type)
		end
	end

	# Fully working
	def generateDotProd(type)
		if type.isNumber && chance(0.15)
			vecType = type.vecType(dimension())
			return "#{generateDotProd(vecType)} .* #{generateMatrixMult(vecType)}"
		else
			return generateMatrixMult(type)
		end
	end

	# Fully working
	def generateMatrixMult(type)
		sharedDim = dimension()
		# Matrix x Vector or Vector x Matrix multiplication yields vector
		if type.isVector && chance(0.4) && type.x > 1
			return chance(0.5) ? "#{generateMatrixMult(type.vecType(sharedDim))} # #{generateSubrange(type.matType(sharedDim, type.x))}" : "#{generateMatrixMult(type.matType(type.x, sharedDim))} # #{generateSubrange(type.vecType(sharedDim))}"
		# Matrix x Matrix multiplication yields matrix if both result dimensions are > 1
		elsif type.isMatrix && chance(0.3) && (type.x > 1 && type.y > 1)
			return "#{generateMatrixMult(type.matType(type.x, sharedDim))} # #{generateSubrange(type.matType(sharedDim, type.y))}"
		# Vector x Vector multiplication yields scalar
		elsif type.isNumber && chance(0.2)
			vecType = type.vecType(sharedDim)
			return "#{generateMatrixMult(vecType)} # #{generateSubrange(vecType)}"
		else
			return generateSubrange(type)
		end
	end

	# Fully working
	def generateSubrange(type)
		if type.isNumber && chance(0.1)
			if chance(0.75)
				dim = dimension()
				vecType = type.vecType(dim)
				offset = ((dim * Random::rand()) - dim/2).to_i
				return "#{generateElementSelect(vecType)} {#{ConstantExpression::generate(offset)} : #{generateExpr(Type::newInt)} : #{ConstantExpression::generate(offset)}}"
			else
				dimX = dimension()
				dimY = dimension()
				matType = type.matType(dimX, dimY)
				offsetX = ((dimX * Random::rand()) - dimX/2).to_i
				offsetY = ((dimY * Random::rand()) - dimY/2).to_i
				return "#{generateElementSelect(matType)} {#{ConstantExpression::generate(offsetX)} : #{generateExpr(Type::newInt)} : #{ConstantExpression::generate(offsetX)} }{ #{ConstantExpression::generate(offsetY)} : #{generateExpr(Type::newInt)} : #{ConstantExpression::generate(offsetY)}}"
			end
		elsif type.isVector && chance(0.1) && type.x > 1 # Generating a 1d vector would result in a scalar value
			if chance(0.75)
				dim = type.x + Random::rand(0..5)
				a = Random::rand(-5..5)
				b = type.x - 1 + a
				l = a < b ? a : b
				u = a < b ? b : a
				vecType = type.vecType(dim)
				return "#{generateElementSelect(vecType)} {#{ConstantExpression::generate(l)} : #{generateExpr(Type::newInt)} : #{ConstantExpression::generate(u)}}"
			else
				a = Random::rand(-5..5)
				b = type.x - 1 + a
				l = a < b ? a : b
				u = a < b ? b : a
				n = Random::rand(-5..5)
				matType = type.matType(dimension(), type.x + Random::rand(0..5))
				return "#{generateElementSelect(matType)} {#{ConstantExpression::generate(n)} : #{generateExpr(Type::newInt)} : #{ConstantExpression::generate(n)} }{ #{ConstantExpression::generate(l)} : #{generateExpr(Type::newInt)} : #{ConstantExpression::generate(u)}}"
			end
		elsif type.isMatrix && chance(0.1) && type.x > 1 # Generating 1xA matrix would result in a vector
			a = Random::rand(-5..5)
			b = type.x - 1 + a
			l1 = a < b ? a : b
			u1 = a < b ? b : a

			a = Random::rand(-5..5)
			b = type.y - 1 + a
			l2 = a < b ? a : b
			u2 = a < b ? b : a
			matType = type.matType(type.x + Random::rand(0..5), type.y + Random::rand(0..5))
			l1Expr = ConstantExpression::generate(l1)
			u1Expr =  ConstantExpression::generate(u1)
			l2Expr =  ConstantExpression::generate(l2)
			u2Expr =  ConstantExpression::generate(u2)
			#STDERR.puts("#{l1} -> #{l1Expr}")
			#STDERR.puts("#{u1} -> #{u1Expr}")
			#STDERR.puts("#{l2} -> #{l2Expr}")
			#STDERR.puts("#{u2} -> #{u2Expr}")
			return "#{generateElementSelect(matType)} {#{l1Expr} : #{generateExpr(Type::newInt)} : #{u1Expr} }{ #{l2Expr} : #{generateExpr(Type::newInt)} : #{u2Expr}}"
		else	
			generateElementSelect(type)
		end
	end

	# Fully working
	def generateElementSelect(type)
		if type.isNumber && chance(0.2)
			cols = dimension()
			selected = (Random::rand()*cols).to_i
			return "#{generateAtom(type.vecType(cols))} [#{generateExpr(Type::newInt)}]"
		elsif type.isVector && chance(0.2)
			rows = dimension()
			selected = (Random::rand()*rows).to_i
			return "#{generateAtom(type.matType(rows, type.x))}[#{generateExpr(Type::newInt)}]"
		else
			generateAtom(type)
		end
	end

	def generateAtom(type)

		if chance(0.05)
			return "( #{generateExpr(type)} )"
		elsif chance(0.5)
			objects = @scope.thingsOfType(type, @records)
			if objects.length > 0
				obj = objects.sample

				if obj.isRecord && type.typeSymbol != :record
					i = @records.getTypes(obj.recordId).index(type)
					elemName = @records.getNames(obj.recordId)[i]
					if obj.structureType == :func
						params = obj.arguments.map{ |arg| generateExpr(arg)}.join(', ')
						return "#{obj.id}(#{params}) @ #{elemName}"
					else
						return "#{obj.id} @ #{elemName}"
					end
				elsif obj.structureType == :val || obj.structureType == :var
					return obj.id
				elsif obj.structureType == :func && chance(0.4)
					params = obj.arguments.map{ |arg| generateExpr(arg)}.join(', ')
					return "#{obj.id}(#{params})"
				end
			end
		end

		case type.typeSymbol
		when :bool
			return ["true", "false"].sample
		when :int
			return (Random::rand()*1000).to_i.to_s
		when :float
			return (Random::rand()*20).round(5).to_s
		when :intvec
			return generateInlineIntVector(type.x)
		when :floatvec
			return generateInlineFloatVector(type.x)
		when :intmat
			return generateInlineMatrix(type.x, type.y, true)
		when :floatmat
			return generateInlineMatrix(type.x, type.y, false)
		when :string
			return "\""+@@strings.sample+"\""
		when :record
			elems = @records.getTypes(type.id).map{ |arg| generateExpr(arg)}.join(', ')
			return "@ #{type.id} [#{elems}]"
		end
	end

	def generateInlineIntVector(x)
		values = []
		x.times do
			if true#chance(0.6)
				values.push((Random::rand()*1000).to_i.to_s)
			elsif chance(0.7)
				values.push(ConstantExpression::generate(Random::rand(-100..100)))
			else
				values.push(generateExpr(Type::newInt))
			end
		end
		return "[#{values.join(', ')}]"
	end

	def generateInlineFloatVector(x)
		values = []
		x.times do
			if chance(0.8)
				values.push( 1.5)# (Random::rand()*20).round(5).to_s)
			else
				values.push(generateExpr(Type::newFloat))
			end
		end
		return "[#{values.join(', ')}]"
	end

	def generateInlineMatrix(x, y, isInt)
		values = []
		x.times do
			values.push(isInt ? generateInlineIntVector(y) : generateInlineFloatVector(y))
		end
		return "[#{values.join(', ')}]"
	end

	def chance(prob)
		Random::rand() < prob
	end

	def dimension
		(Random::rand()*@maxDimension).to_i + 1
	end

	def setMaxDim(mdim)
		@maxDimension = mdim
	end

	def randomType(noRecords = false)
		if chance(0.6)
			return Type.new([:int, :int, :float, :bool, :string].sample)
		elsif chance(0.5)
			return Type.new([:intvec, :floatvec].sample, dimension())
		elsif chance(0.4) && @records.haveRecord && !noRecords
			return @records.randomRecord()
		else
			return Type.new([:intmat, :floatmat].sample, dimension(), dimension())
		end
	end

	def self.prettyPrint(program)
		indentLevel = 0
		res = ""
		wasNewline = true
		lastWord = ""
		program.split(' ').each.with_index { |word, i|
			if word == '{'
				indentLevel += 1
				res = res + (wasNewline ? "{\n" : " {\n") + self.indentation(indentLevel)
				wasNewline = true
			elsif word == '}'
				indentLevel -= 1
				res = res + "\n" + self.indentation(indentLevel) + "}\n" + self.indentation(indentLevel)
				wasNewline = true
			elsif word == ';'
				res = res + ";\n" + self.indentation(indentLevel)
				wasNewline = true
			elsif word == '(' || word == ')' || word == ']' || word == ',' || word == '!' || lastWord == '(' || lastWord == '['
				res = res + word
				wasNewline = false
			else
				res = res + (wasNewline ? "" : " ") + word
				wasNewline = false
			end

			lastWord = word
		}
		return res
	end

	def self.indentation(level)
		(["\t"]*(level < 0 ? 0 : level)).join('')
	end
end