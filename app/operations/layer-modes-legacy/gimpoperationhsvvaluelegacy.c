/* GIMP - The GNU Image Manipulation Program
 * Copyright (C) 1995 Spencer Kimball and Peter Mattis
 *
 * gimpoperationvaluemode.c
 * Copyright (C) 2008 Michael Natterer <mitch@gimp.org>
 *               2012 Ville Sokk <ville.sokk@gmail.com>
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

#include <gegl-plugin.h>
#include <cairo.h>
#include <gdk-pixbuf/gdk-pixbuf.h>

#include "libgimpcolor/gimpcolor.h"

#include "../operations-types.h"

#include "gimpoperationhsvvaluelegacy.h"


static gboolean   gimp_operation_hsv_value_legacy_process (GeglOperation       *op,
                                                           void                *in,
                                                           void                *layer,
                                                           void                *mask,
                                                           void                *out,
                                                           glong                samples,
                                                           const GeglRectangle *roi,
                                                           gint                 level);


G_DEFINE_TYPE (GimpOperationHsvValueLegacy, gimp_operation_hsv_value_legacy,
               GIMP_TYPE_OPERATION_LAYER_MODE)


static void
gimp_operation_hsv_value_legacy_class_init (GimpOperationHsvValueLegacyClass *klass)
{
  GeglOperationClass          *operation_class  = GEGL_OPERATION_CLASS (klass);
  GimpOperationLayerModeClass *layer_mode_class = GIMP_OPERATION_LAYER_MODE_CLASS (klass);

  gegl_operation_class_set_keys (operation_class,
                                 "name",        "gimp:hsv-value-legacy",
                                 "description", "GIMP value mode operation",
                                 NULL);

  layer_mode_class->process = gimp_operation_hsv_value_legacy_process;
}

static void
gimp_operation_hsv_value_legacy_init (GimpOperationHsvValueLegacy *self)
{
}

static gboolean
gimp_operation_hsv_value_legacy_process (GeglOperation       *op,
                                         void                *in_p,
                                         void                *layer_p,
                                         void                *mask_p,
                                         void                *out_p,
                                         glong                samples,
                                         const GeglRectangle *roi,
                                         gint                 level)
{
  GimpOperationLayerMode *layer_mode = (gpointer) op;
  gfloat                 *in         = in_p;
  gfloat                 *out        = out_p;
  gfloat                 *layer      = layer_p;
  gfloat                 *mask       = mask_p;
  gfloat                  opacity    = layer_mode->opacity;
  gint                    total      = samples * 4;
  gfloat                  layer_hsv[total];
  gfloat                  out_hsv[total];
  gfloat                  out_rgb[total];

  /* Convert the entire sample first, then use the HSV values from out_rgb
   * as needed. */
  babl_process (babl_fish (babl_format ("R'G'B'A float"), babl_format ("HSVA float")),
                layer, layer_hsv, samples);
  babl_process (babl_fish (babl_format ("R'G'B'A float"), babl_format ("HSVA float")),
                in, out_hsv, samples);

  for (gint i = 0; i < samples; i++)
    out_hsv2[(i * 4) + 2] = layer_hsv2[(i * 4) + 2];

  babl_process (babl_fish (babl_format ("HSVA float"), babl_format ("R'G'B'A float")),
                out_hsv2, out_rgb, samples);

  for (gint i = 0; i < samples; i++)
    {
      gfloat comp_alpha, new_alpha;
      gint   offset = i * 4;

      comp_alpha = MIN (in[offset + ALPHA], layer[offset + ALPHA]) * opacity;
      if (mask)
        comp_alpha *= *mask;

      new_alpha = in[offset + ALPHA] + (1.0f - in[offset + ALPHA]) * comp_alpha;

      if (comp_alpha && new_alpha)
        {
          gint   b;
          gfloat ratio = comp_alpha / new_alpha;

          for (b = RED; b < ALPHA; b++)
            out[offset + b] = out_rgb[offset + b] * ratio + in[offset + b] * (1.0f - ratio);
        }
      else
        {
          gint b;

          for (b = RED; b < ALPHA; b++)
            {
              out[offset + b] = in[offset + b];
            }
        }

      out[offset + ALPHA] = in[offset + ALPHA];

      if (mask)
        mask++;
    }

  return TRUE;
}
