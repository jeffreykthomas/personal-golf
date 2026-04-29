import { Controller } from "@hotwired/stimulus"
import cytoscape from "cytoscape"

const STATUS_COLORS = {
  draft: "#64748b",
  pending_research: "#f59e0b",
  ready: "#22c55e",
  rebalancing: "#a855f7",
  archived: "#475569"
}

const ROOT_PALETTE = [
  "#38bdf8", "#f472b6", "#a78bfa", "#fb7185", "#facc15",
  "#34d399", "#fb923c", "#60a5fa", "#f87171", "#c084fc"
]

const EDGE_STYLE = {
  hierarchy: { color: "#475569", width: 2, style: "solid" },
  related: { color: "#38bdf8", width: 2, style: "dashed" },
  wikilink: { color: "#a78bfa", width: 2, style: "dotted" },
  source_context: { color: "#94a3b8", width: 1, style: "dotted" }
}

export default class extends Controller {
  static targets = ["canvas", "search", "statusFilter", "relationFilter", "info", "infoTitle", "infoMeta", "infoSummary", "infoLink", "empty"]
  static values = {
    nodes: Array,
    edges: Array,
    nodeUrlTemplate: String
  }

  connect() {
    if (!this.nodesValue || this.nodesValue.length === 0) {
      this.emptyTarget?.classList.remove("hidden")
      this.canvasTarget?.classList.add("hidden")
      return
    }

    this.rootColors = this.assignRootColors(this.nodesValue)
    this.cy = this.buildCytoscape()
    this.bindEvents()
    this.applyFilters()
  }

  disconnect() {
    if (this.cy) {
      this.cy.destroy()
      this.cy = null
    }
  }

  assignRootColors(nodes) {
    const rootIds = [...new Set(nodes.map((n) => n.root_id))]
    const map = {}
    rootIds.forEach((id, idx) => {
      map[id] = ROOT_PALETTE[idx % ROOT_PALETTE.length]
    })
    return map
  }

  buildCytoscape() {
    const elements = []

    this.nodesValue.forEach((node) => {
      elements.push({
        group: "nodes",
        data: {
          id: `n${node.id}`,
          rawId: node.id,
          label: node.title,
          status: node.status,
          rootId: node.root_id,
          isRoot: node.is_root,
          summary: node.summary,
          sourceCount: node.source_count,
          updatedAt: node.updated_at,
          slug: node.slug
        }
      })
    })

    this.edgesValue.forEach((edge) => {
      elements.push({
        group: "edges",
        data: {
          id: edge.id,
          source: `n${edge.source}`,
          target: `n${edge.target}`,
          kind: edge.kind
        }
      })
    })

    return cytoscape({
      container: this.canvasTarget,
      elements,
      style: this.cytoscapeStyle(),
      layout: this.layoutOptions(),
      wheelSensitivity: 0.2,
      minZoom: 0.2,
      maxZoom: 3
    })
  }

  cytoscapeStyle() {
    const rootColors = this.rootColors

    return [
      {
        selector: "node",
        style: {
          "background-color": (ele) => rootColors[ele.data("rootId")] || "#38bdf8",
          "border-width": (ele) => (ele.data("isRoot") ? 3 : 1),
          "border-color": (ele) => STATUS_COLORS[ele.data("status")] || "#64748b",
          "label": "data(label)",
          "color": "#e2e8f0",
          "font-size": (ele) => (ele.data("isRoot") ? 14 : 11),
          "font-weight": (ele) => (ele.data("isRoot") ? 600 : 400),
          "text-outline-color": "#0b1220",
          "text-outline-width": 2,
          "text-valign": "bottom",
          "text-margin-y": 6,
          "text-wrap": "wrap",
          "text-max-width": 140,
          "width": (ele) => (ele.data("isRoot") ? 36 : 22),
          "height": (ele) => (ele.data("isRoot") ? 36 : 22)
        }
      },
      {
        selector: "node.dimmed",
        style: { "opacity": 0.15, "text-opacity": 0.15 }
      },
      {
        selector: "node.highlighted",
        style: { "border-width": 4, "border-color": "#facc15" }
      },
      {
        selector: "edge",
        style: {
          "curve-style": "bezier",
          "line-color": (ele) => (EDGE_STYLE[ele.data("kind")] || EDGE_STYLE.hierarchy).color,
          "line-style": (ele) => (EDGE_STYLE[ele.data("kind")] || EDGE_STYLE.hierarchy).style,
          "width": (ele) => (EDGE_STYLE[ele.data("kind")] || EDGE_STYLE.hierarchy).width,
          "target-arrow-shape": (ele) => (ele.data("kind") === "hierarchy" ? "triangle" : "none"),
          "target-arrow-color": (ele) => (EDGE_STYLE[ele.data("kind")] || EDGE_STYLE.hierarchy).color,
          "opacity": 0.7
        }
      },
      {
        selector: "edge.dimmed",
        style: { "opacity": 0.05 }
      },
      {
        selector: "edge.hidden",
        style: { "display": "none" }
      }
    ]
  }

  layoutOptions() {
    return {
      name: "cose",
      animate: false,
      fit: true,
      padding: 60,
      idealEdgeLength: 110,
      nodeRepulsion: 8000,
      gravity: 0.6,
      numIter: 1500
    }
  }

  bindEvents() {
    this.cy.on("tap", "node", (event) => {
      const node = event.target
      this.showInfo(node.data())
    })

    this.cy.on("dbltap", "node", (event) => {
      const rawId = event.target.data("rawId")
      this.navigateToNode(rawId)
    })

    this.cy.on("tap", (event) => {
      if (event.target === this.cy) {
        this.clearInfo()
      }
    })
  }

  showInfo(data) {
    if (!this.hasInfoTarget) return

    this.cy.nodes().removeClass("highlighted")
    this.cy.$id(`n${data.rawId}`).addClass("highlighted")

    this.infoTarget.classList.remove("hidden")
    this.infoTitleTarget.textContent = data.label
    const meta = []
    if (data.status) meta.push(this.humanize(data.status))
    if (typeof data.sourceCount === "number") meta.push(`${data.sourceCount} sources`)
    if (data.updatedAt) {
      const dt = new Date(data.updatedAt)
      if (!isNaN(dt)) meta.push(`Updated ${dt.toLocaleDateString()}`)
    }
    this.infoMetaTarget.textContent = meta.join(" • ")
    this.infoSummaryTarget.textContent = data.summary || "No summary yet."

    if (this.hasInfoLinkTarget && this.nodeUrlTemplateValue) {
      this.infoLinkTarget.href = this.nodeUrlTemplateValue.replace("__ID__", data.rawId)
    }
  }

  clearInfo() {
    this.cy.nodes().removeClass("highlighted")
    if (this.hasInfoTarget) this.infoTarget.classList.add("hidden")
  }

  navigateToNode(rawId) {
    if (!this.nodeUrlTemplateValue) return
    window.location.href = this.nodeUrlTemplateValue.replace("__ID__", rawId)
  }

  openSelected() {
    const highlighted = this.cy.nodes(".highlighted")
    if (highlighted.length === 0) return
    this.navigateToNode(highlighted[0].data("rawId"))
  }

  applyFilters() {
    const query = this.hasSearchTarget ? this.searchTarget.value.trim().toLowerCase() : ""
    const statusValues = this.selectedFilterValues(this.statusFilterTargets)
    const relationValues = this.selectedFilterValues(this.relationFilterTargets)

    this.cy.batch(() => {
      this.cy.edges().forEach((edge) => {
        const kind = edge.data("kind")
        if (relationValues.length > 0 && !relationValues.includes(kind)) {
          edge.addClass("hidden")
        } else {
          edge.removeClass("hidden")
        }
      })

      this.cy.nodes().forEach((node) => {
        const data = node.data()
        const matchesText = !query || data.label.toLowerCase().includes(query)
        const matchesStatus = statusValues.length === 0 || statusValues.includes(data.status)

        if (matchesText && matchesStatus) {
          node.removeClass("dimmed")
        } else {
          node.addClass("dimmed")
        }
      })

      this.cy.edges(".hidden").connectedNodes().forEach((node) => {
        // no-op; node visibility is governed by text/status only
      })

      this.cy.edges().not(".hidden").forEach((edge) => {
        if (edge.source().hasClass("dimmed") || edge.target().hasClass("dimmed")) {
          edge.addClass("dimmed")
        } else {
          edge.removeClass("dimmed")
        }
      })
    })
  }

  selectedFilterValues(targets) {
    return targets.filter((el) => el.checked).map((el) => el.value)
  }

  recenter() {
    if (!this.cy) return
    this.cy.fit(undefined, 60)
  }

  rerunLayout() {
    if (!this.cy) return
    this.cy.layout(this.layoutOptions()).run()
  }

  humanize(value) {
    return String(value).replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())
  }
}
