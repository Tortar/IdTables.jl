
using IndexedStructVectors
using Test
using Tables

@testset "table interface" begin

	table = IdTable(a=[1,2], b=["a","b"])

	@test Tables.istable(typeof(table))
	@test Tables.rowaccess(typeof(table))
	@test Tables.columnaccess(typeof(table))

	@test table.a == [1,2]

	tablecols = Tables.columns(table)
	@test Tables.getcolumn(tablecols, :a) == [1,2]
	@test Tables.getcolumn(tablecols, 1) == [1,2]
	@test Tables.columnnames(tablecols) == (:id, :a, :b)

	tablerows = Tables.rows(table)
	tablerow = first(tablerows)
	@test eltype(table) == typeof(tablerow)

	@test tablerow.a == 1
	@test Tables.getcolumn(tablerow, :a) == 1
	@test Tables.getcolumn(tablerow, 1) == 1
	@test propertynames(table) == propertynames(tablerow) == (:id, :a, :b)
end