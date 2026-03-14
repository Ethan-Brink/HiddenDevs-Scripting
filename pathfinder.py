import heapq
import random
import time
from collections import deque
from dataclasses import dataclass, field
from typing import Optional

@dataclass
class Node:
    """Represents a single cell on the grid."""
    row: int
    col: int
    walkable: bool = True
    g_cost: float = float("inf")   # Cost from start
    h_cost: float = 0.0            # Heuristic to end
    parent: Optional["Node"] = field(default=None, repr=False)

    @property
    def f_cost(self) -> float:
        return self.g_cost + self.h_cost

    def reset(self):
        self.g_cost = float("inf")
        self.h_cost = 0.0
        self.parent = None

    def __lt__(self, other: "Node") -> bool:
        return self.f_cost < other.f_cost

    def __eq__(self, other) -> bool:
        return isinstance(other, Node) and self.row == other.row and self.col == other.col

    def __hash__(self):
        return hash((self.row, self.col))


@dataclass
class PathResult:
    """Holds the result of a pathfinding run."""
    algorithm: str
    path: list
    visited_count: int
    path_length: int
    duration_ms: float
    found: bool

    def summary(self) -> str:
        if self.found:
            return (
                f"[{self.algorithm}] Path found! "
                f"Length: {self.path_length} | "
                f"Visited: {self.visited_count} | "
                f"Time: {self.duration_ms:.2f}ms"
            )
        return f"[{self.algorithm}] No path found. Visited: {self.visited_count} | Time: {self.duration_ms:.2f}ms"

class Grid:
    """Manages the 2D grid of nodes."""

    def __init__(self, rows: int, cols: int):
        self.rows = rows
        self.cols = cols
        self.nodes: list[list[Node]] = [
            [Node(r, c) for c in range(cols)] for r in range(rows)
        ]

    def get(self, row: int, col: int) -> Optional[Node]:
        if 0 <= row < self.rows and 0 <= col < self.cols:
            return self.nodes[row][col]
        return None

    def reset_costs(self):
        """Reset pathfinding data on all nodes without touching walls."""
        for row in self.nodes:
            for node in row:
                node.reset()

    def get_neighbors(self, node: Node, allow_diagonal: bool = False) -> list[Node]:
        """Return walkable neighbors of a node."""
        directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        if allow_diagonal:
            directions += [(-1, -1), (-1, 1), (1, -1), (1, 1)]

        neighbors = []
        for dr, dc in directions:
            neighbor = self.get(node.row + dr, node.col + dc)
            if neighbor and neighbor.walkable:
                neighbors.append(neighbor)
        return neighbors

    def generate_obstacles(self, density: float = 0.25, seed: int = None):
        """Randomly place walls at a given density."""
        if seed is not None:
            random.seed(seed)
        for row in self.nodes:
            for node in row:
                node.walkable = random.random() > density

    def clear_obstacles(self):
        for row in self.nodes:
            for node in row:
                node.walkable = True

    def display(self, path: list = None, start: Node = None, end: Node = None):
        """Print a visual representation of the grid in the terminal."""
        path_set = set((n.row, n.col) for n in path) if path else set()

        for r in range(self.rows):
            row_str = ""
            for c in range(self.cols):
                node = self.nodes[r][c]
                if start and node == start:
                    row_str += " S "
                elif end and node == end:
                    row_str += " E "
                elif (r, c) in path_set:
                    row_str += " * "
                elif not node.walkable:
                    row_str += " █ "
                else:
                    row_str += " . "
            print(row_str)
        print()

class Heuristic:
    """Collection of heuristic functions for A*."""

    @staticmethod
    def manhattan(a: Node, b: Node) -> float:
        return abs(a.row - b.row) + abs(a.col - b.col)

    @staticmethod
    def euclidean(a: Node, b: Node) -> float:
        return ((a.row - b.row) ** 2 + (a.col - b.col) ** 2) ** 0.5

    @staticmethod
    def chebyshev(a: Node, b: Node) -> float:
        return max(abs(a.row - b.row), abs(a.col - b.col))

class PathfinderBase:
    """Abstract base for all pathfinding algorithms."""

    def __init__(self, grid: Grid):
        self.grid = grid

    def _reconstruct_path(self, end: Node) -> list[Node]:
        path = []
        current = end
        while current is not None:
            path.append(current)
            current = current.parent
        path.reverse()
        return path

    def find_path(self, start: Node, end: Node) -> PathResult:
        raise NotImplementedError


class AStarPathfinder(PathfinderBase):
    """A* search algorithm using Manhattan heuristic."""

    def find_path(self, start: Node, end: Node) -> PathResult:
        self.grid.reset_costs()
        start.g_cost = 0
        start.h_cost = Heuristic.manhattan(start, end)

        open_heap: list[Node] = []
        heapq.heappush(open_heap, start)
        open_set = {start}
        closed_set = set()
        visited_count = 0

        t0 = time.perf_counter()

        while open_heap:
            current = heapq.heappop(open_heap)
            open_set.discard(current)

            if current == end:
                duration = (time.perf_counter() - t0) * 1000
                path = self._reconstruct_path(end)
                return PathResult("A*", path, visited_count, len(path), duration, True)

            closed_set.add(current)
            visited_count += 1

            for neighbor in self.grid.get_neighbors(current):
                if neighbor in closed_set:
                    continue

                tentative_g = current.g_cost + 1

                if tentative_g < neighbor.g_cost:
                    neighbor.g_cost = tentative_g
                    neighbor.h_cost = Heuristic.manhattan(neighbor, end)
                    neighbor.parent = current

                    if neighbor not in open_set:
                        heapq.heappush(open_heap, neighbor)
                        open_set.add(neighbor)

        duration = (time.perf_counter() - t0) * 1000
        return PathResult("A*", [], visited_count, 0, duration, False)


class DijkstraPathfinder(PathfinderBase):
    """Dijkstra's algorithm — uniform cost search."""

    def find_path(self, start: Node, end: Node) -> PathResult:
        self.grid.reset_costs()
        start.g_cost = 0

        open_heap = [(0, start)]
        visited = set()
        visited_count = 0

        t0 = time.perf_counter()

        while open_heap:
            cost, current = heapq.heappop(open_heap)

            if current in visited:
                continue
            visited.add(current)
            visited_count += 1

            if current == end:
                duration = (time.perf_counter() - t0) * 1000
                path = self._reconstruct_path(end)
                return PathResult("Dijkstra", path, visited_count, len(path), duration, True)

            for neighbor in self.grid.get_neighbors(current):
                if neighbor in visited:
                    continue
                new_cost = current.g_cost + 1
                if new_cost < neighbor.g_cost:
                    neighbor.g_cost = new_cost
                    neighbor.parent = current
                    heapq.heappush(open_heap, (new_cost, neighbor))

        duration = (time.perf_counter() - t0) * 1000
        return PathResult("Dijkstra", [], visited_count, 0, duration, False)


class BFSPathfinder(PathfinderBase):
    """Breadth-First Search — guarantees shortest path on unweighted grids."""

    def find_path(self, start: Node, end: Node) -> PathResult:
        self.grid.reset_costs()

        queue = deque([start])
        visited = {start}
        visited_count = 0

        t0 = time.perf_counter()

        while queue:
            current = queue.popleft()
            visited_count += 1

            if current == end:
                duration = (time.perf_counter() - t0) * 1000
                path = self._reconstruct_path(end)
                return PathResult("BFS", path, visited_count, len(path), duration, True)

            for neighbor in self.grid.get_neighbors(current):
                if neighbor not in visited:
                    visited.add(neighbor)
                    neighbor.parent = current
                    queue.append(neighbor)

        duration = (time.perf_counter() - t0) * 1000
        return PathResult("BFS", [], visited_count, 0, duration, False)

class BenchmarkRunner:
    """Runs all algorithms on the same grid and compares results."""

    def __init__(self, grid: Grid):
        self.grid = grid
        self.algorithms: list[PathfinderBase] = [
            AStarPathfinder(grid),
            DijkstraPathfinder(grid),
            BFSPathfinder(grid),
        ]

    def run_all(self, start: Node, end: Node) -> list[PathResult]:
        results = []
        for algo in self.algorithms:
            result = algo.find_path(start, end)
            results.append(result)
        return results

    def print_comparison(self, results: list[PathResult]):
        print("=" * 55)
        print("         PATHFINDING ALGORITHM COMPARISON")
        print("=" * 55)
        for r in results:
            print(r.summary())
        print("=" * 55)

        found = [r for r in results if r.found]
        if len(found) > 1:
            fastest = min(found, key=lambda r: r.duration_ms)
            fewest = min(found, key=lambda r: r.visited_count)
            print(f"⚡ Fastest:        {fastest.algorithm} ({fastest.duration_ms:.2f}ms)")
            print(f"🔍 Fewest visited: {fewest.algorithm} ({fewest.visited_count} nodes)")
        print("=" * 55)

def main():
    ROWS, COLS = 15, 30
    OBSTACLE_DENSITY = 0.25
    SEED = 42

    print(f"\nGrid: {ROWS}x{COLS} | Obstacle density: {OBSTACLE_DENSITY*100:.0f}% | Seed: {SEED}\n")

    grid = Grid(ROWS, COLS)
    grid.generate_obstacles(density=OBSTACLE_DENSITY, seed=SEED)

    # Force start and end to be walkable
    start = grid.get(0, 0)
    end = grid.get(ROWS - 1, COLS - 1)
    start.walkable = True
    end.walkable = True

    # Display grid before pathfinding
    print("Grid layout (S=Start, E=End, █=Wall, .=Open):")
    grid.display(start=start, end=end)

    # Run all algorithms
    runner = BenchmarkRunner(grid)
    results = runner.run_all(start, end)

    # Print comparison
    runner.print_comparison(results)

    # Visualize A* path
    astar_result = next((r for r in results if r.algorithm == "A*"), None)
    if astar_result and astar_result.found:
        print("\nA* path visualization (* = path):")
        grid.display(path=astar_result.path, start=start, end=end)


if __name__ == "__main__":
    main()