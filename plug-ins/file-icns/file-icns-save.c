/* GIMP - The GNU Image Manipulation Program
 * Copyright (C) 1995-1999 Spencer Kimball and Peter Mattis
 *
 * file-icns-save.c
 * Copyright (C) 2004 Brion Vibber <brion@pobox.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include "config.h"

#include <errno.h>
#include <string.h>

#include <glib/gstdio.h>

#include <libgimp/gimp.h>
#include <libgimp/gimpui.h>

#include "file-icns.h"
#include "file-icns-data.h"
#include "file-icns-load.h"
#include "file-icns-save.h"

#include "libgimp/stdplugins-intl.h"

GtkWidget *        icns_dialog_new       (IcnsSaveInfo *info);

static gboolean    icns_save_dialog      (IcnsSaveInfo *info,
                                          GimpImage    *image);

void               icns_dialog_add_icon  (GtkWidget    *dialog,
                                          GimpDrawable *layer,
                                          gint          layer_num);

static GtkWidget * icns_preview_new      (GimpDrawable *layer);

static GtkWidget * icns_create_icon_hbox (GtkWidget    *icon_preview,
                                          GimpDrawable *layer,
                                          gint          layer_num,
                                          IcnsSaveInfo *info);

static gboolean    icns_check_dimensions (gint          width,
                                          gint          height);
static gboolean    icns_check_compat     (GtkWidget    *dialog,
                                          IcnsSaveInfo *info);

GimpPDBStatusType  icns_export_image     (GFile        *file,
                                          IcnsSaveInfo *info,
                                          GimpImage    *image,
                                          GError      **error);

static void        icns_save_info_free   (IcnsSaveInfo *info);

/* Referenced from plug-ins/file-ico/ico-dialog.c */
void
icns_dialog_add_icon (GtkWidget    *dialog,
                      GimpDrawable *layer,
                      gint          layer_num)
{
  GtkWidget    *vbox;
  GtkWidget    *hbox;
  GtkWidget    *preview;
  gchar         key[ICNS_MAXBUF];
  IcnsSaveInfo *info;

  vbox = g_object_get_data (G_OBJECT (dialog), "icons_vbox");
  info = g_object_get_data (G_OBJECT (dialog), "save_info");

  preview = icns_preview_new (layer);
  hbox = icns_create_icon_hbox (preview, layer, layer_num, info);
  gtk_box_pack_start (GTK_BOX (vbox), hbox, FALSE, FALSE, 0);
  gtk_widget_show (hbox);

  /* Let's make the hbox accessible through the layer ID */
  g_snprintf (key, sizeof (key), "layer_%i_hbox",
              gimp_item_get_id (GIMP_ITEM (layer)));
  g_object_set_data (G_OBJECT (dialog), key, hbox);

  icns_check_compat (dialog, info);
}

static GtkWidget *
icns_preview_new (GimpDrawable *layer)
{
  GtkWidget *image;
  GdkPixbuf *pixbuf;
  gint       width  = gimp_drawable_get_width (layer);
  gint       height = gimp_drawable_get_height (layer);

  pixbuf = gimp_drawable_get_thumbnail (layer,
                                        MIN (width, 128), MIN (height, 128),
                                        GIMP_PIXBUF_SMALL_CHECKS);
  image = gtk_image_new_from_pixbuf (pixbuf);

  g_object_unref (pixbuf);

  return image;
}

static gboolean
icns_check_dimensions (gint width, gint height)
{
  gboolean isValid = TRUE;

  if (width != height)
    {
      /* Only valid non-square size is 16x12 */
      if (! (width == 16 && height == 12))
        isValid = FALSE;
    }
  else
    {
      /* Valid square ICNS sizes */
      if (width != 16   &&
          width != 18   &&
          width != 24   &&
          width != 32   &&
          width != 36   &&
          width != 48   &&
          width != 64   &&
          width != 128  &&
          width != 256  &&
          width != 512  &&
          width != 1024)
        isValid = FALSE;
    }

  return isValid;
}

static GtkWidget *
icns_create_icon_hbox (GtkWidget    *icon_preview,
                       GimpDrawable *layer,
                       gint          layer_num,
                       IcnsSaveInfo *info)
{
  static GtkSizeGroup *size = NULL;

  GtkWidget *hbox;
  GtkWidget *vbox;

  hbox = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 6);

  /* To make life easier for the callbacks, we store the
     layer's ID and stacking number with the hbox. */

  g_object_set_data (G_OBJECT (hbox),
                     "icon_layer", layer);
  g_object_set_data (G_OBJECT (hbox),
                     "icon_layer_num", GINT_TO_POINTER (layer_num));

  g_object_set_data (G_OBJECT (hbox), "icon_preview", icon_preview);
  gtk_widget_set_halign (icon_preview, GTK_ALIGN_END);
  gtk_widget_set_valign (icon_preview, GTK_ALIGN_CENTER);
  gtk_box_pack_start (GTK_BOX (hbox), icon_preview, FALSE, FALSE, 0);
  gtk_widget_show (icon_preview);

  if (! size)
    size = gtk_size_group_new (GTK_SIZE_GROUP_HORIZONTAL);

  gtk_size_group_add_widget (size, icon_preview);

  vbox = gtk_box_new (GTK_ORIENTATION_VERTICAL, 2);
  gtk_box_pack_start (GTK_BOX (hbox), vbox, FALSE, FALSE, 0);
  gtk_widget_show (vbox);

  if (! icns_check_dimensions (gimp_drawable_get_width (layer),
                               gimp_drawable_get_height (layer)))
    {
      GtkWidget *label;
      gchar     *warning = g_strdup_printf (_("%d x %d is invalid for ICNS\n"
                                              "It will not be exported"),
                                              gimp_drawable_get_width (layer),
                                              gimp_drawable_get_height (layer));
      gchar     *markup = g_strdup_printf ("<b>%s</b>", warning);

      label = gtk_label_new (NULL);
      gtk_label_set_markup (GTK_LABEL (label), markup);
      g_free (markup);
      g_free (warning);

      gtk_box_pack_start (GTK_BOX (vbox), label, FALSE, FALSE, 0);
      gtk_widget_show (label);
    }

  return hbox;
}

static gboolean
icns_check_compat (GtkWidget    *dialog,
                   IcnsSaveInfo *info)
{
  GtkWidget *warning;
  GList     *iter;
  gboolean   warn = FALSE;
  gint       i;

  for (iter = info->layers, i = 0; iter; iter = iter->next, i++)
    {
      gint width  = gimp_drawable_get_width (iter->data);
      gint height = gimp_drawable_get_height (iter->data);

      warn = ! icns_check_dimensions (width, height);
      if (warn)
        break;
    }

  if (dialog)
    {
      warning = g_object_get_data (G_OBJECT (dialog), "warning");
      gtk_widget_set_visible (warning, warn);
    }

  return ! warn;
}

GtkWidget *
icns_dialog_new (IcnsSaveInfo *info)
{
  GtkWidget     *dialog;
  GtkWidget     *main_vbox;
  GtkWidget     *vbox;
  GtkWidget     *frame;
  GtkWidget     *scrolled_window;
  GtkWidget     *viewport;
  GtkWidget     *warning;

  dialog = gimp_export_dialog_new (_("Apple Icon Image"),
                                   PLUG_IN_BINARY,
                                   "plug-in-icns-save");

  g_object_set_data (G_OBJECT (dialog), "save_info", info);

  main_vbox = gtk_box_new (GTK_ORIENTATION_VERTICAL, 6);
  gtk_container_set_border_width (GTK_CONTAINER (main_vbox), 6);
  gtk_box_pack_start (GTK_BOX (gimp_export_dialog_get_content_area (dialog)),
                      main_vbox, TRUE, TRUE, 0);
  gtk_widget_show (main_vbox);

  warning = g_object_new (GIMP_TYPE_HINT_BOX,
                          "icon-name", GIMP_ICON_DIALOG_WARNING,
                          "hint",
                          _("Valid ICNS icons sizes are:\n "
                            "16x12, 16x16, 18x18, 24x24, 32x32, 36x36, 48x48,\n"
                            "64x64, 128x128, 256x256, 512x512, and 1024x1024.\n"
                            "Any other sized layers will be ignored on export."),
                          NULL);
  gtk_box_pack_end (GTK_BOX (main_vbox), warning, FALSE, FALSE, 12);
  /* Don't show warning by default */

  frame = gimp_frame_new (_("Export Icons"));
  gtk_box_pack_start (GTK_BOX (main_vbox), frame, TRUE, TRUE, 4);
  gtk_widget_show (frame);

  scrolled_window = gtk_scrolled_window_new (NULL, NULL);
  gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (scrolled_window),
                                  GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
  gtk_container_add (GTK_CONTAINER (frame), scrolled_window);
  gtk_widget_show (scrolled_window);

  viewport = gtk_viewport_new (NULL, NULL);
  gtk_container_add (GTK_CONTAINER (scrolled_window), viewport);
  gtk_widget_show (viewport);

  vbox = gtk_box_new (GTK_ORIENTATION_VERTICAL, 6);
  gtk_container_set_border_width (GTK_CONTAINER (vbox), 6);
  g_object_set_data (G_OBJECT (dialog), "icons_vbox", vbox);
  gtk_container_add (GTK_CONTAINER (viewport), vbox);
  gtk_widget_show (vbox);

  g_object_set_data (G_OBJECT (dialog), "warning", warning);

  return dialog;
}

static gboolean
icns_save_dialog (IcnsSaveInfo *info,
                  GimpImage    *image)
{
  GtkWidget     *dialog;
  GList         *iter;
  gint           i;
  gint           response;

  gimp_ui_init (PLUG_IN_BINARY);

  dialog = icns_dialog_new (info);
  for (iter = info->layers, i = 0;
       iter;
       iter = g_list_next (iter), i++)
    icns_dialog_add_icon (dialog, iter->data, i);

  /* Scale the thing to approximately fit its content, but not too large ... */
  gtk_window_set_default_size (GTK_WINDOW (dialog),
                               -1,
                               200 + (info->num_icons > 4 ?
                                      500 : info->num_icons * 120));

  gtk_widget_show (dialog);

  response = gimp_dialog_run (GIMP_DIALOG (dialog));

  gtk_widget_destroy (dialog);

  return (response == GTK_RESPONSE_OK);
}

GimpPDBStatusType
icns_export_image (GFile        *file,
                   IcnsSaveInfo *info,
                   GimpImage    *image,
                   GError      **error)
{
  FILE           *fp;
  GList          *iter;
  gint            i;
  gint            j;
  guint32         file_size   = 8;
  GimpValueArray *return_vals = NULL;

  fp = g_fopen (g_file_peek_path (file), "wb");

  if (! fp)
    {
      icns_save_info_free (info);
      g_set_error (error, G_FILE_ERROR, g_file_error_from_errno (errno),
                   _("Could not open '%s' for writing: %s"),
                   gimp_file_get_utf8_name (file), g_strerror (errno));
      return GIMP_PDB_EXECUTION_ERROR;
    }

  /* Write Header */
  fwrite ("icns", sizeof (gchar), 4, fp);
  fwrite ("\0\0\0\0", sizeof (gchar), 4, fp);  /* will be filled in later */

  /* Write Icon Data */
  for (iter = info->layers, i = 0;
       iter;
       iter = g_list_next (iter), i++)
    {
      gint match  = -1;
      gint width  = gimp_drawable_get_width (iter->data);
      gint height = gimp_drawable_get_height (iter->data);

      /* Don't export icons with invalid dimensions */
      if (! icns_check_dimensions (width, height))
        continue;

      for (j = 0; iconTypes[j].type; j++)
        {
          /* TODO: Currently, this chooses the first "modern" ICNS format for a
           * ICNS file. This is because newer formats are not supported well in
           * non-native MacOS programs like Inkscape. It'd be nice to design
           * a GUI with enough information for users to make their own decisions
           */
          if (iconTypes[j].width == width   &&
              iconTypes[j].height == height &&
              iconTypes[j].isModern)
            {
              match = j;
              break;
            }
        }

      /* MacOS X format icons */
      if (match != -1)
        {
          GimpDrawable   **drawables = NULL;
          GFile           *temp_file = NULL;
          GimpObjectArray *args;
          FILE            *temp_fp;
          gint             temp_size;
          gint             macos_size;

          temp_file = gimp_temp_file ("png");

          drawables = g_new (GimpDrawable *, 1);
          drawables[0] = iter->data;

          args = gimp_object_array_new (GIMP_TYPE_DRAWABLE, (GObject **) drawables, 1, FALSE);

          return_vals =
            gimp_pdb_run_procedure (gimp_get_pdb (),
                                    "file-png-save",
                                    GIMP_TYPE_RUN_MODE,     GIMP_RUN_NONINTERACTIVE,
                                    GIMP_TYPE_IMAGE,        image,
                                    G_TYPE_INT,             1,
                                    GIMP_TYPE_OBJECT_ARRAY, args,
                                    G_TYPE_FILE,            temp_file,
                                    G_TYPE_BOOLEAN,         FALSE,
                                    G_TYPE_INT,             9,
                                    G_TYPE_BOOLEAN,         FALSE,
                                    G_TYPE_BOOLEAN,         FALSE,
                                    G_TYPE_BOOLEAN,         FALSE,
                                    G_TYPE_BOOLEAN,         FALSE,
                                    G_TYPE_BOOLEAN,         FALSE,
                                    G_TYPE_BOOLEAN,         FALSE,
                                    G_TYPE_NONE);

          gimp_object_array_free (args);
          g_clear_pointer (&drawables, g_free);

          if (GIMP_VALUES_GET_ENUM (return_vals, 0) != GIMP_PDB_SUCCESS)
            {
              icns_save_info_free (info);
              g_set_error (error, 0, 0,
                           "Running procedure 'file-png-save' "
                           "for icns export failed: %s",
                           gimp_pdb_get_last_error (gimp_get_pdb ()));

              return GIMP_PDB_EXECUTION_ERROR;
            }

          temp_fp = g_fopen (g_file_peek_path (temp_file), "rb");
          fseek (temp_fp, 0L, SEEK_END);
          temp_size = ftell (temp_fp);
          fseek (temp_fp, 0L, SEEK_SET);

          g_file_delete (temp_file, NULL, NULL);
          g_object_unref (temp_file);

          fwrite (iconTypes[match].type, sizeof (gchar), 4, fp);
          macos_size = GUINT32_TO_BE (temp_size + 8);
          fwrite (&macos_size, sizeof (macos_size), 1, fp);

          if (temp_size > 0)
            {
              guchar buf[temp_size];

              fread (buf, 1, sizeof (buf), temp_fp);

              if (fwrite (buf, 1, temp_size, fp) < temp_size)
                {
                  icns_save_info_free (info);
                  g_set_error (error, G_FILE_ERROR,
                               g_file_error_from_errno (errno),
                               _("Error writing icns: %s"),
                               g_strerror (errno));
                  return GIMP_PDB_EXECUTION_ERROR;
                }
            }
          fclose (temp_fp);

          file_size += temp_size + 8;
        }

      gimp_progress_update (i / info->num_icons);
    }

  /* Update header with full file size */
  file_size = GUINT32_TO_BE (file_size);
  fseek (fp, 4L, SEEK_SET);
  fwrite (&file_size, sizeof (file_size), 1, fp);

  gimp_progress_update (1.0);

  icns_save_info_free (info);
  fclose (fp);
  return GIMP_PDB_SUCCESS ;
}

static void
icns_save_info_free (IcnsSaveInfo *info)
{
  g_list_free (info->layers);
  memset (info, 0, sizeof (IcnsSaveInfo));
}

GimpPDBStatusType
icns_save_image (GFile      *file,
                 GimpImage  *image,
                 gint32      run_mode,
                 GError    **error)
{
  IcnsSaveInfo info;

  info.layers         = gimp_image_list_layers (image);
  info.num_icons      = g_list_length (info.layers);

  if (run_mode == GIMP_RUN_INTERACTIVE)
    {
      /* Allow user to override default values */
      if (! icns_save_dialog (&info, image))
        return GIMP_PDB_CANCEL;
    }
  else if (run_mode == GIMP_RUN_NONINTERACTIVE)
    {
      if (! icns_check_compat (NULL, &info))
        {
          g_set_error (error, G_FILE_ERROR, 0,
                       _("Invalid layer size(s). Only valid layer sizes are "
                         "16x12, 16x16, 18x18, 24x24, 32x32, 36x36, 48x48,"
                         "64x64, 128x128, 256x256, 512x512, or 1024x1024."));

          return GIMP_PDB_EXECUTION_ERROR;
        }
    }

  gimp_progress_init_printf (_("Exporting '%s'"),
                             gimp_file_get_utf8_name (file));

  return icns_export_image (file, &info, image, error);
}
