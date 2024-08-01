/* GIMP - The GNU Image Manipulation Program
 * Copyright (C) 1995 Spencer Kimball and Peter Mattis
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

#ifndef __APP_GIMP_UNIT_H__
#define __APP_GIMP_UNIT_H__


GimpUnit    * _gimp_unit_new                          (Gimp        *gimp,
                                                       const gchar *identifier,
                                                       gdouble      factor,
                                                       gint         digits,
                                                       const gchar *symbol,
                                                       const gchar *abbreviation,
                                                       const gchar *singular,
                                                       const gchar *plural);


#endif  /*  __APP_GIMP_UNIT_H__  */
