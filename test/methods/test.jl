println("##### methods #####")

using Test
using TreeTools


## Testing equality operator
root_1 = TreeTools.read_newick("$(dirname(pathof(TreeTools)))/../test/methods/tree1.nwk")
root_2 = TreeTools.read_newick("$(dirname(pathof(TreeTools)))/../test/methods/tree1_reordered.nwk")
@testset "Equality `==`" begin
	@test root_1 == root_2
end

@testset "node2tree" begin
	@test typeof(node2tree(root_1)) <: Tree
	@test typeof(node2tree(root_2)) <: Tree
end

# Testing ancestors
@testset "Ancestors" begin
    root_1 = TreeTools.read_newick("$(dirname(pathof(TreeTools)))/../test/methods/tree1.nwk")
    @test TreeTools.isancestor(root_1, root_1.child[1])
    @test TreeTools.isancestor(root_1, root_1.child[1].child[1])
    @test !TreeTools.isancestor(root_1.child[1],root_1.child[2])
    root_2 = TreeTools.read_newick("$(dirname(pathof(TreeTools)))/../test/methods/tree2.nwk")
    @test lca((root_2.child[1].child[1], root_2.child[1].child[2])).label == "ABC"
    @test lca((root_2.child[1].child[1].child[1], root_2.child[1].child[1].child[2], root_2.child[1].child[2])).label == "ABC"
    @test lca((root_2.child[1].child[1], root_2.child[2])).label == "ABCD"
end

@testset "Count" begin
	t1 = node2tree(root_1)
	@test count(isleaf, t1) == 4
	@test count(n -> n.label[1] == 'A', t1) == 3
	@test count(isleaf, t1.lnodes["AB"]) == 2
	@test count(n -> n.label[1] == 'A', t1.lnodes["AB"]) == 2
end

@testset "Copy type" begin
	t1 = Tree(TreeNode(MiscData(Dict(1=>2))))
	tc = copy(t1)
	@test tc.root.data[1] == 2
	t1.root.data[1] = 3
	@test tc.root.data[1] == 2
end

@testset "Copy" begin
	t1 = node2tree(root_1)
	t2 = copy(t1)
	t3 = copy(t1, force_new_tree_label=true)
	t4 = copy(t1, label="tree_4")
	@test typeof(t1) == typeof(t2)
	prunesubtree!(t2, ["A"])
	@test haskey(t1.lnodes, "A")
	@test !haskey(t2.lnodes, "A")
	@test t1.label == t2.label
	@test t1.label != t3.label
	@test t1.label != t4.label
	@test t4.label == "tree_4"
end


@testset "Convert" begin
	t1 = Tree(TreeNode(MiscData(Dict(1=>2))))
	# No op
	@test convert(Tree{MiscData}, t1) === t1
	@test convert(Tree{MiscData}, t1).root.data === t1.root.data

	# Converting to EmptyData and back
	t2 = convert(Tree{TreeTools.EmptyData}, t1)
	t3 = convert(Tree{MiscData}, t2)
	@test typeof(t2) == Tree{TreeTools.EmptyData}
	@test t2.root.data == TreeTools.EmptyData()

	@test typeof(t3) == Tree{TreeTools.MiscData}
	@test !haskey(t3.root.data, 1)

	###

	t1 = Tree(TreeNode(TreeTools.EmptyData()))
	# No op
	@test convert(Tree{TreeTools.EmptyData}, t1) === t1

	# Converting to MiscData and back
	t2 = convert(Tree{TreeTools.MiscData}, t1)
	@test typeof(t2) == Tree{TreeTools.MiscData}
	@test isempty(t2.root.data)

	@test typeof(convert(Tree{TreeTools.EmptyData}, t2)) == Tree{TreeTools.EmptyData}

	##check convert will keep tree labels by default
	t3 = Tree(TreeNode(TreeTools.EmptyData()))
	t3.label = "tree3"
	#while converting to MiscData and back
	@test convert(Tree{TreeTools.MiscData}, t3).label === "tree3"
	@test convert(Tree{TreeTools.EmptyData}, t3).label === "tree3"
	##check label can be changed if specified
	t3 = Tree(TreeNode(TreeTools.EmptyData()))
	t3.label = "tree3"
	@test convert(Tree{TreeTools.MiscData}, t3; label="tree4").label === "tree4"
end

nwk = "(A:3,(B:1,C:1):2);"
@testset "Distance" begin
	t = parse_newick_string(nwk)
	# Branch length
	@test distance(t, "A", "B") == 6
	@test distance(t.lnodes["A"], t.lnodes["B"]) == 6
	@test distance(t, "A", "B") == distance(t, "A", "C")
	@test distance(t.root, t.lnodes["A"]) == 3
	# Topological
	@test distance(t.root, t.lnodes["A"]; topological=true) == 1
	@test distance(t, "A", "B"; topological=true) == distance(t, "A", "C"; topological=true)
	@test distance(t, "A", "B"; topological=true) == 3
	for n in nodes(t)
		@test distance(t[n.label], t[n.label]; topological=true) == 0
		@test distance(t[n.label], t[n.label]; topological=false) == 0
	end
	# tests below can be removed when `divtime` is removed
	@test divtime(t.lnodes["A"], t.lnodes["B"]) == 6
	@test divtime(t.root, t.lnodes["A"]) == 3
end

## The tests below depend on the way internal nodes are labelled
## They may need to be rewritten
nwk = "(A,(B,C));"
@testset "Spanning tree 1" begin
	t = parse_newick_string(nwk)
	@test isempty(TreeTools.branches_in_spanning_tree(t, "A"))
	@test sort(TreeTools.branches_in_spanning_tree(t, "A", "B")) == sort(["A", "B", "NODE_2"])
	@test sort(TreeTools.branches_in_spanning_tree(t, "B", "C")) == sort(["B", "C"])
end

nwk = "((A,B),(D,(E,F,G)));"
@testset "Spanning tree 2" begin
	t = parse_newick_string(nwk)
	tmp = sort(TreeTools.branches_in_spanning_tree(t, "A", "E", "F"))
	@test tmp == sort(["A", "NODE_2", "E", "F", "NODE_4", "NODE_3"])
	@test isempty(TreeTools.branches_in_spanning_tree(t, "E"))
end

@testset "ladderize alphabetically" begin
	t1 = node2tree(TreeTools.parse_newick("((D,A,B),C)"; node_data_type=TreeTools.MiscData); label="t1")
	TreeTools.ladderize!(t1)
	@test write_newick(t1) == "(C,(A,B,D)NODE_2)NODE_1:0;"
end


nwk = "(A,(B,C,D,E,(F,G,H)));"
@testset "binarize" begin
	t = parse_newick_string(nwk)
	TreeTools.rand_times!(t)
	bl(t) = sum(skipmissing(map(x -> x.tau, nodes(t)))) # branch length should stay unchanged
	L = bl(t)
	z = TreeTools.binarize!(t; mode=:balanced)
	@test z == 4
	@test length(SplitList(t)) == 7
	@test bl(t) == L
end



@testset "Midpoint rooting" begin
	nwk = "(A,(B,(C,(D,(E,F)))));"
	@testset "1" begin
		t = parse_newick_string(nwk)
		TreeTools.rand_times!(t)
		TreeTools.root!(t, method=:midpoint, topological=true)
		@test t["C"].anc == t.root
		for n in nodes(t)
			@test (n.isroot && ismissing(n.tau)) || (!n.isroot && !ismissing(n.tau))
		end
	end

	nwk = "(A,(B,(C,(D,E))));"
	@testset "2" begin
		t = parse_newick_string(nwk)
		TreeTools.rand_times!(t)
		TreeTools.root!(t, method=:midpoint, topological=true)
		@test t["C"].anc.anc == t.root
		for n in nodes(t)
			@test (n.isroot && ismissing(n.tau)) || (!n.isroot && !ismissing(n.tau))
		end
		@test distance(t.root, t["A"]; topological=true) == 2 || distance(t.root, t["D"]; topological=true) == 2
	end


	nwk = "(A,((B,(C,D)),E,F,(G,(H,I))));"
	@testset "2" begin
		t = parse_newick_string(nwk)
		TreeTools.rand_times!(t)
		TreeTools.root!(t, method = :midpoint)
		@test t["A"].anc == t.root
		@test t["E"].anc == t.root
		@test t["F"].anc == t.root
	end
end




















