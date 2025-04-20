import * as vscode from 'vscode';
import { addTests } from '../utils/addTests';

export function activate(context: vscode.ExtensionContext) {
	context.subscriptions.push(
		vscode.commands.registerCommand('extension.addTests', async () => {
			const editor = vscode.window.activeTextEditor;
			if (!editor) {
				vscode.window.showErrorMessage('No active editor found.');
				return;
			}

			const document = editor.document;
			const range = editor.selection;
			const edit = new vscode.WorkspaceEdit();

			const progressOptions: vscode.ProgressOptions = {
				location: vscode.ProgressLocation.Notification,
				title: 'Adding Tests',
				cancellable: false,
			};

			await vscode.window.withProgress(progressOptions, async (progress) => {
				await progress.report({ message: 'Adding tests...' });
				await addTests(document, range, edit);
			});
		} catch (error) {
			if (error instanceof Error) {
				vscode.window.showErrorMessage(`Error adding tests: ${error.message}`);
			} else {
				vscode.window.showErrorMessage('An unknown error occurred while adding tests.');
			}
		});
	}
}