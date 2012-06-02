<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">
    <xsl:template match="/jobs">
        <html>
            <head>
                <script src="../jscript/sorttable.js" type="text/javascript" charset="utf-8"/>
                <link rel="stylesheet" type="text/css" href="../assets/screen.css"/>
            </head>
            <body>
                <table border="1" class="sortable">
                    <tr>
                        <th>Area</th>
                        <th>Task</th>
                        <th>Comment</th>
                        <th>Action</th>
                    </tr>
                    <xsl:apply-templates select="job"/>
                </table>
            </body>
        </html>
    </xsl:template>
    <xsl:template match="job">
        <tr>
            <td>
                <xsl:value-of select="area"/>
            </td>
            <td>
                <xsl:value-of select="task"/>
                <xsl:if test="link">
                    <span>&#160;<a href="{link}">Link</a>
                    </span>
                </xsl:if>
            </td>
            <td>
                <xsl:value-of select="comment"/>
            </td>
            <td>
                <xsl:value-of select="action"/>
            </td>
        </tr>
    </xsl:template>
</xsl:stylesheet>