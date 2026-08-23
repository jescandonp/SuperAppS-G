@echo off
REM Doble clic para levantar el entorno de pruebas del MVP I9: base con datos simulados, API y
REM cliente web. Los servicios se detienen al pulsar Enter en la ventana que se abre.
REM
REM   Probar-I9.cmd            arranca conservando lo que haya del ciclo anterior
REM   Probar-I9.cmd -Reset     vuelve a crear el esquema de pruebas desde cero
REM
REM Todo ocurre sobre el esquema PostgreSQL sg_i9_pruebas. No toca datos productivos.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-SgSuperAppI9Pruebas.ps1" %*
