---
title: "Correct Canvas Theming for Storybook 10 with MUI 7"
shorttitle: "MUI Storybook Canvas Theming"
description: "a simple and elegant solution instead of unmaintainable degenerative AI trainwreck code slob."
---

# Correct Canvas Theming for Storybook 10 with MUI 7

What if ... you simply want to have Storybook's automated documentation using
the same theme as the sidebar? And then correctly working interactive theme
switching for the rendered components, preferably defaulting to the sidebar's
theme at start?

## Complete f·AI·l

Friends don't let friends waste precious lifetime on degenerative AI vomitting
[Psychomagnotheric
Slime](https://en.wikipedia.org/wiki/Ray_Stantz#Ghostbusters_II_(1989)) code, it
is enough that I tried and ended up with 5× the necessary code ... and that slob
was only _sometimes working somewhat_.

To add insult to the injury, Storybook's own [Integrate Material UI with
Storybook recipe](https://storybook.js.org/recipes/@mui/material/) is partly
slob leading users into wrong directions. 🤦‍♂️

## Starting Point

My current web UI app project setup for the renovation of
[lxkns](http://github.com/thediveo/lxkns) is as follows at the time of writing:

- [React](https://react.dev/) 19 (19.2),
- [Vite](https://vite.dev/) 7 (7.3),
- [MUI](https://mui.com/) 7 (7.3),
- [Storybook](https://storybook.js.org/) 10 (10.1)
  - @storybook/addon-docs 10 (10.1),
  - @storybook/addon-themes 10 (10.1)

## `main.ts`

My `main.ts` is pretty run-of-the-mill and shown here just for completeness: it
pulls in the `@storybook/addon-themes` and `@storybook/addon-docs` add-ons.

```ts
import type { StorybookConfig as StorybookViteConfig } from '@storybook/react-vite'
import { mdxConfiguration } from '../src/mdxconfig.ts'

const config: StorybookViteConfig = {
    framework: {
        name: '@storybook/react-vite',
        options: {},
    },

    stories: [
        '../src/**/*.stories.@(ts|tsx)',
        '../src/*.mdx',
    ],

    addons: [
        '@storybook/addon-docs',
        '@storybook/addon-themes',
    ],

    docs: {
        defaultName: 'Description',
    },

    core: {
        disableTelemetry: true,
        disableWhatsNewNotifications: true,
    },

    typescript: {
        check: true,
    },

}

export default config
```

## Autodocs Theme Sync

We start by fixing the annoying behavior of addon-docs that the automatic
documentation always uses a light theme. Instead, we make it to take on the same
light or dark theme as the storybook's sidebar using the magic `themes.normal`:
this is automatically initialized to either `"light"` or `"dark"` depending on
the browser's or system's configured color scheme preference.

Put the following into your `preview.tsx`:

```tsx
// preview.tsx
import type { Parameters, Preview } from '@storybook/react-vite'
import { themes } from 'storybook/theming'

export const parameters: Parameters = {
    docs: {
        theme: themes.normal, // use same theme as the surrounding parts
    },
}
```

Ah, that's much better and one eyesore less:

![synchronized autodocs theme](_images/storybook-same-theme.png)

## Light/Dark MUI Themes

Next, we need a light and a dark MUI theme; the simplest way is to simply do...

```tsx
// preview.tsx
const lightTheme = createTheme({ palette: { mode: 'light' } })
const darkTheme = createTheme({ palette: { mode: 'dark' } })
```

...and let MUI do the heavy lifting. Here, we pass
[`createTheme`](https://mui.com/material-ui/customization/theming/#createtheme-options-args-theme)
just a minimalist theme object that then gets filled with the missing elements.

In your own MUI application you might have already done some theme customization
and added [custom
variables](https://mui.com/material-ui/customization/theming/#custom-variables),
such as covering colors for specific components outside the scope of MUI itself.

## Preview Wrap

And here comes the real "know-how" part where I could not find any documentation
and where storybook's own AI bot -- as well as other AI systems -- were
producing only absolute crap. Instead, simply looking[^console.log] at what gets
passed as a so-called `context` to preview decorator functions reveals a global
[`backgrounds`](https://storybook.js.org/docs/essentials/backgrounds#configuration)
"feature" -- while `backgrounds` is documented with certain fields, there's a
`value` field that isn't documented.

Playing around with the theme selector for the automatically generated
documentation (see screenshot) thankfully changes this `value` field...

![autodocs theme selector](_images/storybook-theme-selector.png)

...where the values of `value` (yes, naming is hard) are:

- `undefined`, that is, not present,
- `light`,
- `dark`.

All we need to do, is to use `context.globals.backgrounds?.value` if set, or
otherwise fall back to the detected color scheme preference from
`themes.normal.base`.

Then it's the usual wrapping hierarchy of MUI's `StyledEngineProvider` and
`ThemeProvider` (with the correct concrete theme palette settings, et cetera).
Let's finally throw in a `MemoryRouter` so we can also work with components that
in our application do navigation or need to know the current route. We use
`context.parameters` with out self-invented `routerProps` element that, if
present, is passed to the `MemoryRouter`; otherwise, we apply sensible defaults
to our memory router component.

```tsx
// preview.tsx
const preview: Preview = {
    decorators: [
        (Story, context) => {
            const isDark = (context.globals.backgrounds?.value || themes.normal.base) === 'dark'

            const routerProps = context.parameters.routerProps || 
                { initialEntries: ["/"] }

            return (
                <StyledEngineProvider injectFirst>
                    <ThemeProvider theme={isDark ? darkTheme : lightTheme} >
                        <CssBaseline enableColorScheme />
                        <MemoryRouter {...routerProps}>
                            <Story />
                        </MemoryRouter>
                    </ThemeProvider>
                </StyledEngineProvider>
            )
        },
    ],
}

export default preview
```

We can now select which theme to use for rendering our components in our
stories, using the "change background" menu button at the top left of an
automatically generated story:

![autodoc canvas theme selection](_images/storybook-autodoc-theme-light.png)

Job done.

## `preview.tsx`

That's it, all in a single place and with the usual MUI boilerplate (and maybe a
tiny bit more). `lxknsLightTheme` and `lxknsDarkTheme` are two 

```tsx
import type { Parameters, Preview } from '@storybook/react-vite'
import { themes } from 'storybook/theming'

import '@fontsource/roboto/300.css'
import '@fontsource/roboto/400.css'
import '@fontsource/roboto/500.css'
import '@fontsource/roboto/700.css'
import '@fontsource/roboto-mono/400.css'

import { MemoryRouter } from "react-router-dom"
import { lxknsDarkTheme, lxknsLightTheme } from 'styles/themes'
import { StyledEngineProvider, ThemeProvider, createTheme } from '@mui/material/styles'
import CssBaseline from '@mui/material/CssBaseline'

const lightTheme = createTheme(
    { palette: { mode: 'light' } }, lxknsLightTheme)
const darkTheme = createTheme(
    { palette: { mode: 'dark' } }, lxknsDarkTheme)

export const parameters: Parameters = {
    docs: {
        theme: themes.normal, // use same theme as the surrounding parts
    },
}

const preview: Preview = {
    decorators: [
        (Story, context) => {
            const isDark = (context.globals.backgrounds?.value || themes.normal.base) === 'dark'

            const routerProps = context.parameters.routerProps || 
                { initialEntries: ["/"] }

            return (
                <StyledEngineProvider injectFirst>
                    <ThemeProvider theme={isDark ? darkTheme : lightTheme} >
                        <CssBaseline enableColorScheme />
                        <MemoryRouter {...routerProps}>
                            <Story />
                        </MemoryRouter>
                    </ThemeProvider>
                </StyledEngineProvider>
            )
        },
    ],
}

export default preview
```

#### Notes

[^console.log]: oh, these wonders of primeval logging!
