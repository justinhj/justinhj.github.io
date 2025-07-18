# Justin's technical blog Function[Justin]
## Where the main layout is defined
When editing the main layout look in _layouts/

## Testing changes
The user will have the site constantly rebuilding using the Jekyll server command so you don't have to run it it.
You can use the playwright tool to view the site in the browser to answer the users questions and verify your changes.
If the site is not running it may be because there is an error, ask the user to copy the error for you.
The site runs on localhost port 4003.

## Bugs and improvements
1. In the pre src org-mode code blocks the text goes off to the right out of the dark background.
  + Fixed
2. The popular posts screen does not use the same card layout as the posts screen.

## CSS Organization

The primary CSS for this Jekyll site is managed through Sass.

- **Main Sass File:** The main entry point for the site's CSS is `/css/main.scss`. This file contains variable definitions and imports the other Sass partials.

- **Sass Partials:** The `_sass` directory contains the individual Sass partials, which are organized by component (e.g., `_header.scss`, `_footer.scss`, `_layout.scss`). These files are imported into `main.scss`.

One of the key files to edit to change appearance is _sass/_base.scss, which contains the base styles for the site.

- **Org Mode CSS:** The `_orgcss/site.css` file contains styles specifically for content that has been generated from Org mode files.

- **Editing CSS:** To edit the site's CSS, you should modify the appropriate `.scss` file in the `_sass` directory and then recompile the Jekyll site. Changes to `main.scss` will also require a recompilation. The `_orgcss/site.css` file can be edited directly.

- **Jekyll Configuration:** The `_config.yml` file includes the `css` and `_orgcss` directories in the site build, ensuring that the compiled CSS is available to the site.

## Site Structure

This Jekyll site follows the standard Jekyll directory structure.

*   `_config.yml`: Stores site-wide configuration data.
*   `_posts`: Contains blog posts, which must be named with the `YEAR-MONTH-DAY-title.MARKUP` format.
*   `_includes`: Contains reusable elements like partials.
*   `_layouts`: Contains the main templates for the site.
*   `_site`: The output directory where the generated site is placed.
*   `_data`: For site data.
*   `_drafts`: For unpublished posts.
*   `_sass`: For Sass partials.
*   `css`: Contains the main `main.scss` file.
*   `_orgcss`: Contains CSS for Org mode generated files.
*   `assets` or other directories: Jekyll will also copy over any other directories you create to the generated site.
