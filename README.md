# emaki.nvim

Read PDFs in Neovim as one continuously scrolling document.

An *emaki* (絵巻) is an illustrated handscroll, read by unrolling it steadily
from one end to the other. This plugin does the same thing to a PDF: every page
is rendered as an image and stacked down a single buffer, so `j`, `<C-d>` and
`/` move through the document the way they move through any other buffer.

Only the pages near the viewport are rendered, so a three hundred page paper
opens as quickly as a three page one.

> [!IMPORTANT]
> This needs a terminal that implements the kitty graphics protocol **with
> unicode placeholders** — in practice **kitty** or **Ghostty**. WezTerm draws
> images at a fixed window position rather than in buffer cells, so stacked
> pages cannot scroll there. Run `:checkhealth emaki` to see where you stand.

## Requirements

- Neovim 0.10+
- [snacks.nvim](https://github.com/folke/snacks.nvim) with the `image` module enabled
- kitty or Ghostty
- `pdfinfo` and `pdftotext` (poppler-utils)
- Ghostscript (`gs`) and ImageMagick (`magick`, or `convert` for ImageMagick 6)
- tmux users: `set -g allow-passthrough on`

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "KinjiKawaguchi/emaki.nvim",
  dependencies = {
    { "folke/snacks.nvim", opts = { image = { enabled = true } } },
  },
  opts = {},
}
```

Then open any `.pdf`.

## Keymaps

Buffer-local, active only in a PDF buffer. Ordinary motions still scroll.

| Key | Action |
| --- | --- |
| `]p` / `[p` | next / previous page |
| `]P` / `[P` | last / first page |
| `+` / `-` | zoom in / out |
| `=` | fit the page to the window width |
| `<leader>pg` | jump to a page number |
| `<leader>pt` | extract the text layer into a new tab |

`:EmakiInspect` prints the measured geometry, which is what to include in a bug
report about pages being the wrong size.

## Configuration

Defaults shown; pass any subset to `opts`.

```lua
{
  gap = 2,                    -- blank lines between pages
  min_cols = 20,              -- narrowest page, in cells
  zoom_step = 10,             -- columns per zoom step
  preload_pages = 1,          -- pages rendered beyond the viewport
  density = 240,              -- rasterisation dpi; bounds useful zoom
  patch_snacks_convert = true,-- see below
  keys = { ... },             -- set any entry to false to skip it
  wo = { ... },               -- window options for the viewer
  winbar = function(info) ... end,
}
```

### `patch_snacks_convert`

Left alone, snacks renders a PDF page in two ways that break a paged layout.

It passes `-trim`, cropping each page to its ink bounding box. That discards the
paper aspect ratio this plugin derives row counts from, and makes every page a
different size depending on how much is written on it.

It also rasterises at some DPI and then reports that same DPI in the resulting
image, so its pixels-to-cells conversion cancels out. The effect is a hard
ceiling near 99 columns for an A4 page, on every terminal and at every font
size, which on a wide window leaves the page occupying roughly half the screen.

With this option on, emaki rewrites `Snacks.image.config.convert.magick.pdf` to
drop the trim and to report a lower DPI than it rasterised at. This is a global
change and also affects PDFs embedded in documents. Set it to `false` to keep
your own arguments, and expect undersized pages.

## Limitations

- **kitty and Ghostty only**, as above.
- **No text selection or in-document search.** The buffer holds blank lines with
  images laid over them, so `/` finds nothing. `<leader>pt` gives you the text in
  a separate buffer. A positioned invisible text layer is possible and is the
  main thing this plugin is missing.
- **No horizontal panning.** The placeholder grid is anchored to a fixed window
  column, so zoom is capped at the window width.
- **297 cells per page in each direction.** snacks encodes an image cell's row
  and column as combining diacritics on `U+10EEEE`, and only 297 exist.
- **Scanned PDFs** render fine but have no text to extract.
- **Encrypted PDFs** are not supported.
- Over SSH each page image is base64 encoded across the connection. Lower
  `density` if scrolling feels heavy.

## How it works

`pdfinfo` gives the page count and paper size. From the paper size and the
terminal's cell dimensions, each page is assigned a fixed block of buffer lines.
The buffer is filled with that many blank lines, and `Snacks.image.placement` is
asked to overlay page *n* across page *n*'s line range as extmark virtual text.

Because the image lives in the buffer's cells rather than at a screen position,
it scrolls with the text for free. On every scroll the pages outside the
viewport are closed and the ones entering it are created.

## Credits

The rendering is entirely [snacks.nvim](https://github.com/folke/snacks.nvim)
(Apache-2.0, © folke): the kitty graphics protocol, unicode placeholders, the
conversion pipeline, terminal detection, and tmux passthrough. emaki only decides
which page belongs on which line. If you want images in Neovim generally, you
want snacks, not this.

## License

MIT
